@isTest
public class UpdateDateFieldActionTest {
    @isTest
    static void testUpdateDateFieldAction() {
        // Arrange
        Opportunity testOpportunity = new Opportunity(Name = 'Test Opportunity', StageName = 'Prospecting', CloseDate = Date.today(), Prospecting_Date_Stamp__c = null);
        insert testOpportunity;

        UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
        request.objectApiName = 'Opportunity';
        request.picklistApiName = 'StageName';
        request.picklistValue = 'Prospecting';
        request.recordId = testOpportunity.Id;
        List<UpdateDateFieldAction.UpdateDateFieldRequest> requests = new List<UpdateDateFieldAction.UpdateDateFieldRequest>{request};

        // Act
        Test.startTest();
        UpdateDateFieldAction.updateDateField(requests);
        Test.stopTest();
    }
}
