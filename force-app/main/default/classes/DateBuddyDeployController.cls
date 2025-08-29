public with sharing class DateBuddyDeployController {
    /**
     * DTO returned to LWC for async status.
     */
    public class AsyncStatusDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String state;
        @AuraEnabled public Boolean done;
        @AuraEnabled public String statusCode;
        @AuraEnabled public String message;
    }

    /**
     * Deploys a before-save trigger for the given object via apex-mdapi.
     * Returns the AsyncResult Id for tracking.
     *
     * Requires the apex-mdapi MetadataService installed in the org and the
     * Visualforce page '/apex/DateBuddySession' to obtain a valid session when needed.
     */
    @AuraEnabled
    public static String deployTrigger(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('objectApiName is required');
        }
        MetadataService.AsyncResult[] results = DateStampTriggerDeployer.deploy(objectApiName);
        if (results == null || results.isEmpty()) {
            throw new AuraHandledException('No async result returned from Metadata API');
        }
        return results[0].id;
    }

    /**
     * Since createMetadata is synchronous, we return a completed status immediately.
     * The deployment happens synchronously, so we just return success.
     */
    @AuraEnabled(cacheable=false)
    public static AsyncStatusDTO getStatus(String asyncId) {
        if (String.isBlank(asyncId)) {
            throw new AuraHandledException('asyncId is required');
        }
        // Since createMetadata is synchronous, we return completed status
        AsyncStatusDTO dto = new AsyncStatusDTO();
        dto.id = asyncId;
        dto.state = 'Completed';
        dto.done = true;
        dto.statusCode = null;
        dto.message = 'Trigger deployed successfully';
        return dto;
    }

    /**
     * Returns a sorted list of SObject API Names that have existing Date_Stamp_Mapping__mdt records.
     * This ensures we only show objects that have been configured for DateBuddy.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> listSObjects() {
        // Query for all Date_Stamp_Mapping__mdt records to get distinct Object_API_Name__c values
        List<Date_Stamp_Mapping__mdt> mappings = [
            SELECT Object_API_Name__c 
            FROM Date_Stamp_Mapping__mdt
        ];
        
        Set<String> objectsWithMappings = new Set<String>();
        for (Date_Stamp_Mapping__mdt mapping : mappings) {
            objectsWithMappings.add(mapping.Object_API_Name__c);
        }
        
        // Verify these objects exist and are valid for triggers
        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        List<String> names = new List<String>();
        
        for (String objName : objectsWithMappings) {
            if (g.containsKey(objName)) {
                Schema.DescribeSObjectResult d = g.get(objName).getDescribe();
                // Ensure the object is valid for triggers
                if (!d.isCustomSetting() && !d.isDeprecatedAndHidden() && 
                    d.isQueryable() && (d.isCreateable() || d.isUpdateable())) {
                    names.add(objName);
                }
            }
        }
        
        names.sort();
        return names;
    }

    /**
     * Returns the generated trigger source for inspection in the UI.
     * This mirrors the deployed content.
     */
    @AuraEnabled(cacheable=true)
    public static String getTriggerSource(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('objectApiName is required');
        }
        String triggerName = DateStampTriggerDeployer.generateTriggerName(objectApiName);
        return DateStampTriggerDeployer.generateTriggerSource(objectApiName, triggerName);
    }
}
