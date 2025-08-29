@IsTest(seeAllData=false)
public class DateBuddyHandlerTest {
    private static void insertMapping(String objectApiName, String picklistApiName, String picklistValue, String dateFieldApiName) {
        Date_Stamp_Mapping__mdt m = new Date_Stamp_Mapping__mdt();
        m.DeveloperName = 'Test_' + objectApiName + '_' + picklistValue.replace(' ', '_');
        m.Label = 'Test Mapping';
        m.Object_API_Name__c = objectApiName;
        m.Picklist_API_Name__c = picklistApiName;
        m.Picklist_Value__c = picklistValue;
        m.Date_Field_API_Name__c = dateFieldApiName;
        insert m;
    }

    @IsTest
    static void testBeforeInsert_setsDateWhenNullAndMatch() {
        insertMapping('Task', 'Status', 'Not Started', 'ActivityDate');

        Task t = new Task(Subject = 'Test', Status = 'Not Started');
        System.assertEquals(null, t.ActivityDate);

        Test.startTest();
        DateBuddyHandler.beforeInsertOrUpdate(new List<SObject>{ t }, null);
        Test.stopTest();

        System.assertEquals(Date.today(), t.ActivityDate, 'ActivityDate should be set to today');
    }

    @IsTest
    static void testBeforeInsert_doesNotOverrideExistingDate() {
        insertMapping('Task', 'Status', 'Not Started', 'ActivityDate');

        Date existing = Date.today().addDays(-5);
        Task t = new Task(Subject = 'Test', Status = 'Not Started', ActivityDate = existing);

        Test.startTest();
        DateBuddyHandler.beforeInsertOrUpdate(new List<SObject>{ t }, null);
        Test.stopTest();

        System.assertEquals(existing, t.ActivityDate, 'Existing date must not be overridden');
    }

    @IsTest
    static void testBeforeInsert_ignoresWhenPicklistValueNotMapped() {
        insertMapping('Task', 'Status', 'Not Started', 'ActivityDate');

        Task t = new Task(Subject = 'Test', Status = 'Completed');

        Test.startTest();
        DateBuddyHandler.beforeInsertOrUpdate(new List<SObject>{ t }, null);
        Test.stopTest();

        System.assertEquals(null, t.ActivityDate, 'No date should be set for unmapped picklist values');
    }
}

