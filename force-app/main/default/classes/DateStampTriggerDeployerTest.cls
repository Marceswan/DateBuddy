@IsTest(seeAllData=false)
public class DateStampTriggerDeployerTest {
    @IsTest
    static void testGenerateTriggerName_format() {
        String name = DateStampTriggerDeployer.generateTriggerName('Task');
        System.assertEquals('DateStamp_Task_BT', name);
    }

    @IsTest
    static void testGenerateTriggerSource_contents() {
        String triggerName = DateStampTriggerDeployer.generateTriggerName('Task');
        String src = DateStampTriggerDeployer.generateTriggerSource('Task', triggerName);
        System.assert(src.contains('trigger ' + triggerName), 'Should contain trigger declaration');
        System.assert(src.contains('on Task (before insert, before update)'), 'Should declare before insert/update on Task');
        System.assert(src.contains('DateBuddyHandler.beforeInsertOrUpdate'), 'Should invoke DateBuddyHandler');
    }
}

