@isTest
public class UpdateDateFieldActionTest {
    
    // Helper method to create System Admin user
    private static User createSystemAdminUser() {
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User adminUser = new User(
            FirstName = 'Test',
            LastName = 'Admin',
            Email = 'testadmin@datebuddy.test',
            Username = 'testadmin@datebuddy.test.' + DateTime.now().getTime(),
            Alias = 'tadmin',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = sysAdminProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert adminUser;
        return adminUser;
    }
    
    @testSetup
    static void setupTestData() {
        // Create and run as System Administrator
        User adminUser = createSystemAdminUser();
        
        System.runAs(adminUser) {
            // Create test Account with Type field
            Account testAccount = new Account(Name = 'Test Account', Type = 'Prospect');
            insert testAccount;
            
            // Create test Contact with custom fields if they exist
            Contact testContact = new Contact(
                FirstName = 'Test',
                LastName = 'Contact',
                AccountId = testAccount.Id,
                Email = 'test@example.com'
            );
            insert testContact;
            
            // Create test Opportunity
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            insert testOpp;
        }
    }

    // Helper method to get admin user for tests
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'testadmin@datebuddy.test' LIMIT 1];
    }
    
    @isTest
    static void testUpdateDateFieldUsingHandler() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test that the refactored code delegates to DateBuddyHandler
            Contact testContact = [SELECT Id FROM Contact LIMIT 1];
            
            UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
            request.objectApiName = 'Contact';
            request.picklistApiName = 'LeadSource';
            request.picklistValue = 'Web';
            request.recordId = testContact.Id;
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>{ request });
            Test.stopTest();
            
            // Verify the contact was processed
            Contact updatedContact = [SELECT Id, LeadSource FROM Contact WHERE Id = :testContact.Id];
            System.assertEquals('Web', updatedContact.LeadSource, 'Picklist value should be set');
        }
    }
    
    @isTest
    static void testMultipleRequestsDifferentObjects() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test batch processing of multiple objects
            Contact testContact = [SELECT Id FROM Contact LIMIT 1];
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
            
            List<UpdateDateFieldAction.UpdateDateFieldRequest> requests = new List<UpdateDateFieldAction.UpdateDateFieldRequest>();
            
            // Account request
            UpdateDateFieldAction.UpdateDateFieldRequest req1 = new UpdateDateFieldAction.UpdateDateFieldRequest();
            req1.objectApiName = 'Account';
            req1.picklistApiName = 'Type';
            req1.picklistValue = 'Customer';
            req1.recordId = testAccount.Id;
            requests.add(req1);
            
            // Contact request
            UpdateDateFieldAction.UpdateDateFieldRequest req2 = new UpdateDateFieldAction.UpdateDateFieldRequest();
            req2.objectApiName = 'Contact';
            req2.picklistApiName = 'LeadSource';
            req2.picklistValue = 'Partner Referral';
            req2.recordId = testContact.Id;
            requests.add(req2);
            
            // Opportunity request
            UpdateDateFieldAction.UpdateDateFieldRequest req3 = new UpdateDateFieldAction.UpdateDateFieldRequest();
            req3.objectApiName = 'Opportunity';
            req3.picklistApiName = 'StageName';
            req3.picklistValue = 'Qualification';
            req3.recordId = testOpp.Id;
            requests.add(req3);
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(requests);
            Test.stopTest();
            
            // Verify all records were processed
            Account updatedAccount = [SELECT Id, Type FROM Account WHERE Id = :testAccount.Id];
            System.assertEquals('Customer', updatedAccount.Type, 'Account type should be updated');
            
            Contact updatedContact = [SELECT Id, LeadSource FROM Contact WHERE Id = :testContact.Id];
            System.assertEquals('Partner Referral', updatedContact.LeadSource, 'Contact lead source should be updated');
            
            Opportunity updatedOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :testOpp.Id];
            System.assertEquals('Qualification', updatedOpp.StageName, 'Opportunity stage should be updated');
        }
    }
    
    @isTest
    static void testEmptyRequestList() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test null and empty request lists
            Test.startTest();
            UpdateDateFieldAction.updateDateField(null);
            UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>());
            Test.stopTest();
            
            // Should handle gracefully without errors
            System.assert(true, 'Should handle null/empty requests without error');
        }
    }
    
    @isTest
    static void testWithDirectionParameter() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test that direction parameter is preserved (though not used in current implementation)
            Contact testContact = [SELECT Id FROM Contact LIMIT 1];
            
            UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
            request.objectApiName = 'Contact';
            request.picklistApiName = 'LeadSource';
            request.picklistValue = 'Web';
            request.recordId = testContact.Id;
            request.direction = 'Entering';
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>{ request });
            Test.stopTest();
            
            // Direction is preserved but not used in the handler delegation
            Contact updatedContact = [SELECT Id, LeadSource FROM Contact WHERE Id = :testContact.Id];
            System.assertEquals('Web', updatedContact.LeadSource, 'Picklist value should be set');
        }
    }
    
    @isTest
    static void testMultipleSameObjectRequests() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Get the existing account to associate contacts with
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            // Test multiple requests for the same object type
            List<Contact> contacts = new List<Contact>();
            for (Integer i = 0; i < 5; i++) {
                contacts.add(new Contact(
                    FirstName = 'Test' + i,
                    LastName = 'Contact' + i,
                    AccountId = testAccount.Id,  // Ensure all contacts have an account
                    Email = 'test' + i + '@example.com'
                ));
            }
            insert contacts;
            
            List<UpdateDateFieldAction.UpdateDateFieldRequest> requests = new List<UpdateDateFieldAction.UpdateDateFieldRequest>();
            for (Contact c : contacts) {
                UpdateDateFieldAction.UpdateDateFieldRequest req = new UpdateDateFieldAction.UpdateDateFieldRequest();
                req.objectApiName = 'Contact';
                req.picklistApiName = 'LeadSource';
                req.picklistValue = 'Web';
                req.recordId = c.Id;
                requests.add(req);
            }
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(requests);
            Test.stopTest();
            
            // All contacts should be processed in one batch
            List<Contact> updatedContacts = [SELECT Id, LeadSource FROM Contact WHERE Id IN :contacts];
            for (Contact c : updatedContacts) {
                System.assertEquals('Web', c.LeadSource, 'All contacts should have LeadSource set to Web');
            }
        }
    }
    
    @isTest
    static void testValueAlreadySet() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test when the picklist value is already set
            Contact testContact = [SELECT Id FROM Contact LIMIT 1];
            testContact.LeadSource = 'Web';
            update testContact;
            
            UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
            request.objectApiName = 'Contact';
            request.picklistApiName = 'LeadSource';
            request.picklistValue = 'Web';
            request.recordId = testContact.Id;
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>{ request });
            Test.stopTest();
            
            // Should handle gracefully when value is already set
            Contact updatedContact = [SELECT Id, LeadSource FROM Contact WHERE Id = :testContact.Id];
            System.assertEquals('Web', updatedContact.LeadSource, 'Value should remain as Web');
        }
    }
    
    @isTest
    static void testInvalidFieldNames() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test with non-existent fields (should handle gracefully)
            Contact testContact = [SELECT Id FROM Contact LIMIT 1];
            
            UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
            request.objectApiName = 'Contact';
            request.picklistApiName = 'NonExistentField__c';
            request.picklistValue = 'SomeValue';
            request.recordId = testContact.Id;
            
            Test.startTest();
            try {
                UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>{ request });
                // May throw error depending on field validation
            } catch (Exception e) {
                // Expected for non-existent fields
                System.assert(e.getMessage().contains('No such column') || 
                             e.getMessage().contains('field') ||
                             e.getMessage().contains('Invalid'),
                             'Should get field-related error for non-existent field');
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testWithMockCMDT() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test with mock CMDT to ensure handler is called properly
            Opportunity testOpp = [SELECT Id, StageName FROM Opportunity LIMIT 1];
            
            // Create mock CMDT
            List<Date_Stamp_Mapping__mdt> mockMappings = new List<Date_Stamp_Mapping__mdt>();
            Date_Stamp_Mapping__mdt mockMapping = new Date_Stamp_Mapping__mdt(
                DeveloperName = 'Test_Mock',
                Object_API_Name__c = 'Opportunity',
                Picklist_API_Name__c = 'StageName',
                Picklist_Value__c = 'Closed Won',
                Date_Field_API_Name__c = 'CloseDate',
                Direction__c = 'Entering'
            );
            mockMappings.add(mockMapping);
            
            // Inject mock mappings into handler
            DateBuddyHandler.testMappings = mockMappings;
            
            UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
            request.objectApiName = 'Opportunity';
            request.picklistApiName = 'StageName';
            request.picklistValue = 'Closed Won';
            request.recordId = testOpp.Id;
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>{ request });
            Test.stopTest();
            
            // Clear test mappings
            DateBuddyHandler.testMappings = null;
            
            // Verify opportunity was updated
            Opportunity updatedOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :testOpp.Id];
            System.assertEquals('Closed Won', updatedOpp.StageName, 'Stage should be updated to Closed Won');
        }
    }
    
    @isTest
    static void testLargeVolumeRequests() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Get existing account for associations
            Account existingAccount = [SELECT Id FROM Account LIMIT 1];
            
            // Test with large number of requests to verify performance
            List<Account> accounts = new List<Account>();
            for (Integer i = 0; i < 100; i++) {
                accounts.add(new Account(Name = 'Test Account ' + i, Type = 'Prospect'));
            }
            insert accounts;
            
            List<UpdateDateFieldAction.UpdateDateFieldRequest> requests = new List<UpdateDateFieldAction.UpdateDateFieldRequest>();
            for (Account acc : accounts) {
                UpdateDateFieldAction.UpdateDateFieldRequest req = new UpdateDateFieldAction.UpdateDateFieldRequest();
                req.objectApiName = 'Account';
                req.picklistApiName = 'Type';
                req.picklistValue = 'Customer';
                req.recordId = acc.Id;
                requests.add(req);
            }
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(requests);
            Test.stopTest();
            
            // Verify all accounts were updated
            List<Account> updatedAccounts = [SELECT Id, Type FROM Account WHERE Id IN :accounts];
            System.assertEquals(100, updatedAccounts.size(), 'All accounts should be processed');
            for (Account acc : updatedAccounts) {
                System.assertEquals('Customer', acc.Type, 'All accounts should be Customer type');
            }
        }
    }
    
    @isTest
    static void testMixedObjectsWithDirection() {
        User adminUser = getAdminUser();
        
        System.runAs(adminUser) {
            // Test mixed objects with various direction values
            Contact testContact = [SELECT Id FROM Contact LIMIT 1];
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
            
            List<UpdateDateFieldAction.UpdateDateFieldRequest> requests = new List<UpdateDateFieldAction.UpdateDateFieldRequest>();
            
            // Contact with Entering direction
            UpdateDateFieldAction.UpdateDateFieldRequest req1 = new UpdateDateFieldAction.UpdateDateFieldRequest();
            req1.objectApiName = 'Contact';
            req1.picklistApiName = 'LeadSource';
            req1.picklistValue = 'Web';
            req1.recordId = testContact.Id;
            req1.direction = 'Entering';
            requests.add(req1);
            
            // Account with Exiting direction
            UpdateDateFieldAction.UpdateDateFieldRequest req2 = new UpdateDateFieldAction.UpdateDateFieldRequest();
            req2.objectApiName = 'Account';
            req2.picklistApiName = 'Type';
            req2.picklistValue = 'Customer';
            req2.recordId = testAccount.Id;
            req2.direction = 'Exiting';
            requests.add(req2);
            
            // Opportunity with no direction
            UpdateDateFieldAction.UpdateDateFieldRequest req3 = new UpdateDateFieldAction.UpdateDateFieldRequest();
            req3.objectApiName = 'Opportunity';
            req3.picklistApiName = 'StageName';
            req3.picklistValue = 'Proposal/Price Quote';
            req3.recordId = testOpp.Id;
            requests.add(req3);
            
            Test.startTest();
            UpdateDateFieldAction.updateDateField(requests);
            Test.stopTest();
            
            // Verify all records were processed
            Contact updatedContact = [SELECT Id, LeadSource FROM Contact WHERE Id = :testContact.Id];
            System.assertEquals('Web', updatedContact.LeadSource, 'Contact should have Web lead source');
            
            Account updatedAccount = [SELECT Id, Type FROM Account WHERE Id = :testAccount.Id];
            System.assertEquals('Customer', updatedAccount.Type, 'Account should be Customer type');
            
            Opportunity updatedOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :testOpp.Id];
            System.assertEquals('Proposal/Price Quote', updatedOpp.StageName, 'Opportunity should be in Proposal stage');
        }
    }
}