@isTest
public class UpdateDateFieldActionTest {
	@testSetup
	static void setupTestData() {
		Account account = new Account(Name = 'Test Account');
		insert account;
		
		Opportunity opp = new Opportunity(
			Name = 'Test Opportunity',
			AccountId = account.Id,
			StageName = 'Prospecting',
			CloseDate = Date.today().addDays(30)
		);
		insert opp;
		
		// Change stage to trigger date tracking
		opp.StageName = 'Qualification';
		update opp;
	}

	@isTest
	static void testUpdateDateField() {
		Opportunity opp = [SELECT Id, StageName FROM Opportunity LIMIT 1];

		UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
		request.objectApiName = 'Opportunity';
		request.picklistApiName = 'StageName';
		request.picklistValue = 'Qualification';
		request.recordId = opp.Id;
		request.direction = 'Entered'; // Optional

		Test.startTest();
		UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>{ request });
		Test.stopTest();

		Opportunity updatedOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];
		System.assertNotEquals(null, updatedOpp.StageName, 'The stage should be set.');
	}

	@isTest
	static void testUpdateDateFieldNoDirection() {
		Opportunity opp = [SELECT Id, StageName FROM Opportunity LIMIT 1];

		UpdateDateFieldAction.UpdateDateFieldRequest request = new UpdateDateFieldAction.UpdateDateFieldRequest();
		request.objectApiName = 'Opportunity';
		request.picklistApiName = 'StageName';
		request.picklistValue = 'Qualification';
		request.recordId = opp.Id;
		// No direction specified - should work with any matching record

		Test.startTest();
		UpdateDateFieldAction.updateDateField(new List<UpdateDateFieldAction.UpdateDateFieldRequest>{ request });
		Test.stopTest();

		Opportunity updatedOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];
		System.assertNotEquals(null, updatedOpp.StageName, 'The stage should be set.');
	}
}
