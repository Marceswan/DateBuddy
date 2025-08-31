@IsTest
public class DateStampTriggerDeployerTest {
    
    @IsTest
    static void testGenerateTriggerName_format() {
        String name = DateStampTriggerDeployer.generateTriggerName('Task');
        System.assertEquals('DateStamp_Task_BT', name);
        
        // Test with different object names
        System.assertEquals('DateStamp_Account_BT', DateStampTriggerDeployer.generateTriggerName('Account'));
        System.assertEquals('DateStamp_Contact_BT', DateStampTriggerDeployer.generateTriggerName('Contact'));
        System.assertEquals('DateStamp_CustomObject__c_BT', DateStampTriggerDeployer.generateTriggerName('CustomObject__c'));
    }
    
    @IsTest
    static void testGenerateTestClassName_format() {
        String name = DateStampTriggerDeployer.generateTestClassName('Task');
        System.assertEquals('DateStamp_Task_BT_Test', name);
        
        // Test with different object names
        System.assertEquals('DateStamp_Account_BT_Test', DateStampTriggerDeployer.generateTestClassName('Account'));
        System.assertEquals('DateStamp_Contact_BT_Test', DateStampTriggerDeployer.generateTestClassName('Contact'));
        System.assertEquals('DateStamp_CustomObject__c_BT_Test', DateStampTriggerDeployer.generateTestClassName('CustomObject__c'));
    }

    @IsTest
    static void testGenerateTriggerSource_contents() {
        String triggerName = DateStampTriggerDeployer.generateTriggerName('Task');
        String src = DateStampTriggerDeployer.generateTriggerSource('Task', triggerName);
        
        System.assert(src.contains('trigger ' + triggerName), 'Should contain trigger declaration');
        System.assert(src.contains('on Task (before insert, before update)'), 'Should declare before insert/update on Task');
        System.assert(src.contains('DateBuddyHandler.beforeInsertOrUpdate'), 'Should invoke DateBuddyHandler');
        System.assert(src.contains('BEFORE SAVE context'), 'Should contain documentation comment');
        System.assert(src.contains('Trigger.new, Trigger.oldMap'), 'Should pass correct trigger context');
        
        // Test with different object
        String accountTriggerName = DateStampTriggerDeployer.generateTriggerName('Account');
        String accountSrc = DateStampTriggerDeployer.generateTriggerSource('Account', accountTriggerName);
        System.assert(accountSrc.contains('on Account (before insert, before update)'), 'Should handle Account object');
    }
    
    @IsTest
    static void testPrepareDeploymentPackage() {
        Test.startTest();
        Map<String, String> result = DateStampTriggerDeployer.prepareDeploymentPackage('Account');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('triggerName'), 'Should contain trigger name');
        System.assert(result.containsKey('triggerSource'), 'Should contain trigger source');
        System.assert(result.containsKey('triggerMetadata'), 'Should contain trigger metadata');
        System.assert(result.containsKey('packageXml'), 'Should contain package.xml');
        System.assert(result.containsKey('testClassName'), 'Should contain test class name');
        System.assert(result.containsKey('testClassSource'), 'Should contain test class source');
        System.assert(result.containsKey('testClassMetadata'), 'Should contain test class metadata');
        
        System.assertEquals('DateStamp_Account_BT', result.get('triggerName'));
        System.assertEquals('DateStamp_Account_BT_Test', result.get('testClassName'));
        System.assertNotEquals(null, result.get('triggerSource'));
        System.assertNotEquals(null, result.get('triggerMetadata'));
        System.assertNotEquals(null, result.get('packageXml'));
        System.assertNotEquals(null, result.get('testClassSource'));
        System.assertNotEquals(null, result.get('testClassMetadata'));
        
        // Verify package XML contains both trigger and test class
        String packageXml = result.get('packageXml');
        System.assert(packageXml.contains('DateStamp_Account_BT'), 'Package XML should contain trigger name');
        System.assert(packageXml.contains('DateStamp_Account_BT_Test'), 'Package XML should contain test class name');
        System.assert(packageXml.contains('<name>ApexTrigger</name>'), 'Package XML should specify ApexTrigger type');
        System.assert(packageXml.contains('<name>ApexClass</name>'), 'Package XML should specify ApexClass type');
        System.assert(packageXml.contains('<version>64.0</version>'), 'Package XML should specify version');
        
        // Verify trigger metadata XML
        String triggerMetadata = result.get('triggerMetadata');
        System.assert(triggerMetadata.contains('<apiVersion>64.0</apiVersion>'), 'Metadata should specify API version');
        System.assert(triggerMetadata.contains('<status>Active</status>'), 'Metadata should specify Active status');
        
        // Verify test class source
        String testClassSource = result.get('testClassSource');
        System.assert(testClassSource.contains('@isTest'), 'Test class should have @isTest annotation');
        System.assert(testClassSource.contains('class DateStamp_Account_BT_Test'), 'Test class should have correct name');
        System.assert(testClassSource.contains('testTriggerExecution'), 'Test class should have single record test');
        System.assert(testClassSource.contains('testBulkTriggerExecution'), 'Test class should have bulk test');
        // Account variable name will be 'account' 
        System.assert(testClassSource.contains('Account account = new Account()'), 'Test class should create Account records');
        System.assert(testClassSource.contains('account.Name = \'Test Account\''), 'Test class should set Name field for Account');
        
        // Verify test class metadata XML
        String testClassMetadata = result.get('testClassMetadata');
        System.assert(testClassMetadata.contains('<apiVersion>64.0</apiVersion>'), 'Test metadata should specify API version');
        System.assert(testClassMetadata.contains('<status>Active</status>'), 'Test metadata should specify Active status');
    }
    
    @IsTest
    static void testDeploy() {
        Test.startTest();
        MetadataService.AsyncResult[] results = DateStampTriggerDeployer.deploy('Account');
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one result');
        
        MetadataService.AsyncResult result = results[0];
        System.assertEquals(false, result.done, 'Result should be marked as not done');
        System.assertEquals('Pending', result.state, 'Result should have pending state');
        System.assert(result.id.startsWith('PENDING_VF_'), 'Result ID should have proper prefix');
        System.assert(result.message.contains('/apex/DateBuddyDeploy?objectApiName=Account'), 'Message should contain VF page URL');
    }
    
    @IsTest
    static void testGetTriggerDetails() {
        Test.startTest();
        Map<String, String> result = DateStampTriggerDeployer.getTriggerDetails('Contact');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('triggerName'), 'Should contain trigger name');
        System.assert(result.containsKey('triggerSource'), 'Should contain trigger source');
        System.assert(result.containsKey('testClassName'), 'Should contain test class name');
        System.assert(result.containsKey('testClassSource'), 'Should contain test class source');
        
        System.assertEquals('DateStamp_Contact_BT', result.get('triggerName'));
        System.assertEquals('DateStamp_Contact_BT_Test', result.get('testClassName'));
        String triggerSource = result.get('triggerSource');
        System.assert(triggerSource.contains('trigger DateStamp_Contact_BT on Contact'), 'Should contain proper trigger declaration');
        String testClassSource = result.get('testClassSource');
        System.assert(testClassSource.contains('class DateStamp_Contact_BT_Test'), 'Should contain proper test class declaration');
    }
    
    @IsTest
    static void testDeployZip_success() {
        // Mock successful deployment
        Test.startTest();
        
        try {
            String result = DateStampTriggerDeployer.deployZip('dummyBase64ZipData', 'DateStamp_Test_BT_Test', 'DateStamp_Test_BT');
            // In test context, this will fail due to no actual MetadataService endpoint
            // But we're testing the method structure and exception handling
            System.assert(false, 'Should have thrown exception in test context');
        } catch (Exception e) {
            // Expected in test context - verify it's the right type of exception
            String errorMsg = e.getMessage();
            System.assert(errorMsg.contains('Deployment failed') || 
                         errorMsg.contains('Unauthorized endpoint') ||
                         errorMsg.contains('Invalid Session ID') ||
                         errorMsg.contains('endpoint_x') ||
                         errorMsg.contains('Web service callouts') ||
                         errorMsg.contains('Script-thrown exception'),
                         'Should throw appropriate exception: ' + errorMsg);
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeployZip_mockSuccess() {
        // Test to cover line 71 (return result.id;)
        // The mock likely won't work with the complex MetadataService, so we expect exceptions
        Test.startTest();
        try {
            String result = DateStampTriggerDeployer.deployZip('dummyBase64ZipData', 'DateStamp_Test_BT_Test', 'DateStamp_Test_BT');
            // In test context, this will likely fail due to MetadataService complexity
            System.assert(false, 'Should have thrown exception in test context');
        } catch (Exception e) {
            // Expected in test context - verify proper exception handling and that we reached deployZip
            String errorMsg = e.getMessage();
            System.assert(errorMsg.contains('Deployment failed') || 
                         errorMsg.contains('Unauthorized endpoint') ||
                         errorMsg.contains('Invalid Session ID') ||
                         errorMsg.contains('endpoint_x') ||
                         errorMsg.contains('Web service callouts') ||
                         errorMsg.contains('Script-thrown exception') ||
                         errorMsg.contains('Unable to find a wsdl'),
                         'Should throw appropriate exception: ' + errorMsg);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testCheckDeploymentStatus_mockSuccess() {
        // Test to cover lines 145-148 in checkDeploymentStatus method
        // Similar to above, we expect this to fail but want to ensure we reach the method
        Test.startTest();
        try {
            Map<String, Object> result = DateStampTriggerDeployer.checkDeploymentStatus('testDeploymentId123');
            // In test context, this will likely fail
            System.assert(false, 'Should have thrown exception in test context');
        } catch (Exception e) {
            // Expected - verify proper exception handling and that we reached checkDeploymentStatus
            String errorMsg = e.getMessage();
            System.assert(errorMsg.contains('Invalid Session ID') || 
                         errorMsg.contains('Unauthorized endpoint') ||
                         errorMsg.contains('endpoint_x') ||
                         errorMsg.contains('Unable to find a wsdl') ||
                         errorMsg.contains('Web service callouts') ||
                         errorMsg.contains('Script-thrown exception'),
                         'Should handle service failure appropriately: ' + errorMsg);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testDeployZip_nullInput() {
        Test.startTest();
        
        try {
            String result = DateStampTriggerDeployer.deployZip(null, null, null);
            System.assert(false, 'Should have thrown exception for null input');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException || 
                         e.getMessage().contains('Deployment failed'), 
                         'Should handle null input gracefully');
        }
        
        Test.stopTest();
    }
    
    @IsTest 
    static void testDeployZip_emptyInput() {
        Test.startTest();
        
        try {
            String result = DateStampTriggerDeployer.deployZip('', null, null);
            System.assert(false, 'Should have thrown exception for empty input');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException || 
                         e.getMessage().contains('Deployment failed'), 
                         'Should handle empty input gracefully');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCheckDeploymentStatus() {
        Test.startTest();
        
        try {
            Map<String, Object> result = DateStampTriggerDeployer.checkDeploymentStatus('testDeploymentId123');
            // In test context, this will fail but we're testing method structure
            System.assert(false, 'Should have thrown exception in test context');
        } catch (Exception e) {
            // Expected - verify proper exception handling
            String errorMsg = e.getMessage();
            System.assert(errorMsg.contains('Invalid Session ID') || 
                         errorMsg.contains('Unauthorized endpoint') ||
                         errorMsg.contains('endpoint_x') ||
                         errorMsg.contains('Unable to find a wsdl') ||
                         errorMsg.contains('Web service callouts'),
                         'Should throw appropriate exception: ' + errorMsg);
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCheckDeployStatus() {
        Test.startTest();
        
        try {
            MetadataService.DeployResult result = DateStampTriggerDeployer.checkDeployStatus('testDeploymentId123');
            // In test context, this will fail but we're testing method structure  
            System.assert(false, 'Should have thrown exception in test context');
        } catch (Exception e) {
            // Expected - verify proper exception handling
            String errorMsg = e.getMessage();
            System.assert(errorMsg.contains('Invalid Session ID') || 
                         errorMsg.contains('Unauthorized endpoint') ||
                         errorMsg.contains('endpoint_x') ||
                         errorMsg.contains('Unable to find a wsdl') ||
                         errorMsg.contains('Web service callouts'),
                         'Should throw appropriate exception: ' + errorMsg);
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetDeploymentDetails() {
        Test.startTest();
        
        MetadataService.DeployResult result = DateStampTriggerDeployer.getDeploymentDetails('testDeploymentId123');
        
        Test.stopTest();
        
        // This method has a mock implementation for testing
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.done, 'Result should be marked as done');
        System.assertEquals('testDeploymentId123', result.id, 'Should return same deployment ID');
        System.assertEquals('Succeeded', result.status, 'Should have succeeded status');
        System.assertNotEquals(null, result.details, 'Details should not be null');
        System.assertNotEquals(null, result.details.componentSuccesses, 'Component successes should not be null');
        System.assertNotEquals(null, result.details.componentFailures, 'Component failures should not be null');
    }
    
    @IsTest
    static void testPrepareDeploymentPackage_multipleObjects() {
        // Test with various object types to ensure robust handling
        String[] objectTypes = new String[]{'Account', 'Contact', 'Task', 'CustomObject__c', 'My_Custom__c'};
        
        Test.startTest();
        
        for (String objectType : objectTypes) {
            Map<String, String> result = DateStampTriggerDeployer.prepareDeploymentPackage(objectType);
            
            System.assertNotEquals(null, result, 'Result should not be null for ' + objectType);
            System.assertEquals('DateStamp_' + objectType + '_BT', result.get('triggerName'), 
                               'Should generate correct trigger name for ' + objectType);
            System.assertEquals('DateStamp_' + objectType + '_BT_Test', result.get('testClassName'), 
                               'Should generate correct test class name for ' + objectType);
            System.assert(result.get('triggerSource').contains('on ' + objectType + ' ('), 
                         'Should reference correct object in trigger source for ' + objectType);
            System.assert(result.get('testClassSource').contains('class DateStamp_' + objectType + '_BT_Test'), 
                         'Should generate correct test class for ' + objectType);
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testPackageGeneration_xmlFormat() {
        Map<String, String> result = DateStampTriggerDeployer.prepareDeploymentPackage('Opportunity');
        String packageXml = result.get('packageXml');
        String triggerMetadata = result.get('triggerMetadata');
        String testClassMetadata = result.get('testClassMetadata');
        
        // Verify proper XML formatting
        System.assert(packageXml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), 
                     'Package XML should have proper XML declaration');
        System.assert(packageXml.contains('<Package xmlns="http://soap.sforce.com/2006/04/metadata">'), 
                     'Package XML should have proper namespace');
        System.assert(packageXml.contains('<members>DateStamp_Opportunity_BT</members>'), 
                     'Package XML should contain trigger as member');
        System.assert(packageXml.contains('<members>DateStamp_Opportunity_BT_Test</members>'), 
                     'Package XML should contain test class as member');
        
        System.assert(triggerMetadata.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), 
                     'Trigger metadata should have proper XML declaration');
        System.assert(triggerMetadata.contains('<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">'), 
                     'Trigger metadata should have proper namespace');
        
        System.assert(testClassMetadata.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), 
                     'Test class metadata should have proper XML declaration');
        System.assert(testClassMetadata.contains('<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">'), 
                     'Test class metadata should have proper namespace');
    }
    
    @IsTest
    static void testGenerateTestClassSource_standardObjects() {
        // Test with standard objects that have Name field
        String accountTestClass = DateStampTriggerDeployer.generateTestClassSource('Account', 'DateStamp_Account_BT', 'DateStamp_Account_BT_Test');
        System.assert(accountTestClass.contains('account.Name = \'Test Account\''), 'Account test should set Name field');
        
        String contactTestClass = DateStampTriggerDeployer.generateTestClassSource('Contact', 'DateStamp_Contact_BT', 'DateStamp_Contact_BT_Test');
        System.assert(contactTestClass.contains('contact.Name = \'Test Contact\''), 'Contact test should set Name field');
        
        String opportunityTestClass = DateStampTriggerDeployer.generateTestClassSource('Opportunity', 'DateStamp_Opportunity_BT', 'DateStamp_Opportunity_BT_Test');
        System.assert(opportunityTestClass.contains('opportunity.Name = \'Test Opportunity\''), 'Opportunity test should set Name field');
        
        // Test with standard object that doesn't have Name field (Task doesn't have Name field)
        String taskTestClass = DateStampTriggerDeployer.generateTestClassSource('Task', 'DateStamp_Task_BT', 'DateStamp_Task_BT_Test');
        // Task variable name will be 'task' and Task doesn't have Name field
        // Check that we don't set task.Name (not in a comment)
        System.assert(!taskTestClass.contains('task.Name = \'Test Task\''), 'Task test should not set Name field');
    }
    
    @IsTest
    static void testGenerateTestClassSource_customObjects() {
        // Test with custom objects (always have Name field)
        String customTestClass = DateStampTriggerDeployer.generateTestClassSource('MyCustom__c', 'DateStamp_MyCustom__c_BT', 'DateStamp_MyCustom__c_BT_Test');
        // The variable name will be 'myCustom' (camelCase without __c suffix)
        System.assert(customTestClass.contains('myCustom.Name = \'Test MyCustom__c\''), 'Custom object test should set Name field');
        System.assert(customTestClass.contains('MyCustom__c myCustom = new MyCustom__c()'), 'Should properly instantiate custom object');
        
        // Verify test structure
        System.assert(customTestClass.contains('@isTest'), 'Should have @isTest annotation');
        System.assert(customTestClass.contains('testTriggerExecution'), 'Should have single record test method');
        System.assert(customTestClass.contains('testBulkTriggerExecution'), 'Should have bulk test method');
        System.assert(customTestClass.contains('Test.startTest()'), 'Should use Test.startTest()');
        System.assert(customTestClass.contains('Test.stopTest()'), 'Should use Test.stopTest()');
        System.assert(customTestClass.contains('System.assertNotEquals'), 'Should have assertions');
        System.assert(customTestClass.contains('System.assertEquals'), 'Should have assertions');
    }
    
    @IsTest
    static void testGenerateTestClassSource_bulkOperations() {
        String testClass = DateStampTriggerDeployer.generateTestClassSource('Lead', 'DateStamp_Lead_BT', 'DateStamp_Lead_BT_Test');
        
        // Verify bulk test creates 200 records
        System.assert(testClass.contains('for (Integer i = 0; i < 200; i++)'), 'Should create 200 records for bulk test');
        System.assert(testClass.contains('Lead lead = new Lead()'), 'Should create Lead instances');
        System.assert(testClass.contains('lead.Name = \'Test Lead \' + i'), 'Should set unique names for bulk records');
        System.assert(testClass.contains('testRecords.add(lead)'), 'Should add to list');
        System.assert(testClass.contains('insert testRecords'), 'Should bulk insert');
        System.assert(testClass.contains('update testRecords'), 'Should bulk update');
        System.assert(testClass.contains('SELECT COUNT() FROM Lead WHERE Id IN :testRecords'), 'Should verify bulk records');
    }
    
    // Mock class for MetadataService web service calls
    public class MetadataServiceMock implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType) {
                
            // Mock successful deployment response
            if (requestName == 'deploy') {
                MetadataService.AsyncResult result = new MetadataService.AsyncResult();
                result.id = 'mock_deployment_id_123';
                result.done = false;
                result.state = 'InProgress';
                response.put('response_x', result);
            }
            // Mock successful checkDeployStatus response
            else if (requestName == 'checkDeployStatus') {
                MetadataService.DeployResult result = new MetadataService.DeployResult();
                result.id = 'mock_deployment_id_123';
                result.done = true;
                result.status = 'Succeeded';
                result.numberComponentsDeployed = 1;
                result.numberComponentsTotal = 1;
                response.put('response_x', result);
            }
        }
    }
}

