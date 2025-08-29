public without sharing class DateStampTriggerDeployer {
    /**
     * Deploys a before-save trigger for the provided object using apex-mdapi.
     * Trigger calls DateStampTriggerHandler.beforeInsertOrUpdate.
     */
    public static MetadataService.AsyncResult[] deploy(String objectApiName) {
        String triggerName = generateTriggerName(objectApiName);
        String source = generateTriggerSource(objectApiName, triggerName);

        MetadataService.MetadataPort service = MetadataService.createService();

        MetadataService.ApexTrigger trig = new MetadataService.ApexTrigger();
        trig.fullName = objectApiName + '.' + triggerName;
        trig.content = source;

        return service.create(new MetadataService.Metadata[] { trig });
    }

    public static String generateTriggerName(String objectApiName) {
        return 'DateStamp_' + objectApiName + '_BT';
    }

    public static String generateTriggerSource(String objectApiName, String triggerName) {
        String nl = '\n';
        String body = 'trigger ' + triggerName + ' on ' + objectApiName + ' (before insert, before update) {' + nl +
                      '    DateBuddyHandler.beforeInsertOrUpdate(Trigger.new, Trigger.oldMap);' + nl +
                      '}';
        return body;
    }
}
