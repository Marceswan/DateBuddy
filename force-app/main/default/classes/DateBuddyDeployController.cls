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
     * Polls the Metadata API for async status using apex-mdapi.
     */
    @AuraEnabled(cacheable=false)
    public static AsyncStatusDTO getStatus(String asyncId) {
        if (String.isBlank(asyncId)) {
            throw new AuraHandledException('asyncId is required');
        }
        MetadataService.MetadataPort svc = MetadataService.createService();
        MetadataService.AsyncResult[] results = svc.checkStatus(new String[] { asyncId });
        MetadataService.AsyncResult r = (results != null && results.size() > 0) ? results[0] : null;
        if (r == null) {
            throw new AuraHandledException('No status returned for id: ' + asyncId);
        }
        AsyncStatusDTO dto = new AsyncStatusDTO();
        dto.id = r.id;
        dto.state = r.state;
        dto.done = r.done;
        dto.statusCode = r.statusCode;
        dto.message = r.message;
        return dto;
    }

    /**
     * Returns a sorted list of SObject API Names suitable for trigger deployment.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> listSObjects() {
        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        List<String> names = new List<String>();
        for (Schema.SObjectType t : g.values()) {
            Schema.DescribeSObjectResult d = t.getDescribe();
            if (d.isCustomSetting() || d.isDeprecatedAndHidden()) continue;
            // Heuristic filter: likely business objects
            if (d.isQueryable() && (d.isCreateable() || d.isUpdateable())) {
                names.add(d.getName());
            }
        }
        names.sort();
        return names;
    }
}
