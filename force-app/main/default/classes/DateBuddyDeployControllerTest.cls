@IsTest(seeAllData=false)
public class DateBuddyDeployControllerTest {
    @IsTest
    static void testGetStatus_returnsCompleted() {
        DateBuddyDeployController.AsyncStatusDTO dto = DateBuddyDeployController.getStatus('abc123');
        System.assertEquals('abc123', dto.id);
        System.assertEquals(true, dto.done);
        System.assertEquals('Completed', dto.state);
        System.assertEquals('Trigger deployed successfully', dto.message);
    }

    @IsTest
    static void testDeployTrigger_blankObjectNameThrows() {
        try {
            DateBuddyDeployController.deployTrigger('');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('objectApiName is required'));
        }
    }

    @IsTest
    static void testGetTriggerSource_mirrorsGenerator() {
        String expectedName = DateStampTriggerDeployer.generateTriggerName('Task');
        String fromController = DateBuddyDeployController.getTriggerSource('Task');
        System.assert(fromController.contains('trigger ' + expectedName), 'Should contain generated trigger name');
        System.assert(fromController.contains('on Task (before insert, before update)'));
        System.assert(fromController.contains('DateBuddyHandler.beforeInsertOrUpdate'));
    }

    @IsTest
    static void testListSObjects_containsCoreObject() {
        List<String> names = DateBuddyDeployController.listSObjects();
        System.assert(!names.isEmpty(), 'Should return some SObject names');
        System.assert(names.contains('Task') || names.contains('Account'), 'Should include common SObjects');
    }
}

