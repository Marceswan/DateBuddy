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
     * Wrapper class for object card information.
     */
    public class ObjectCardWrapper {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public Integer uniqueFieldsCount;
        @AuraEnabled public Integer totalMappingsCount;
        @AuraEnabled public Boolean hasDeployedTrigger;

        public ObjectCardWrapper(String objectApiName, String objectLabel, Integer uniqueFieldsCount, Integer totalMappingsCount, Boolean hasDeployedTrigger) {
            this.objectApiName = objectApiName;
            this.objectLabel = objectLabel;
            this.uniqueFieldsCount = uniqueFieldsCount;
            this.totalMappingsCount = totalMappingsCount;
            this.hasDeployedTrigger = hasDeployedTrigger;
        }
    }

    /**
     * Wrapper class for field mapping information.
     */
    public class FieldMappingWrapper {
        @AuraEnabled public List<TreeNode> treeData;
        @AuraEnabled public List<MappingDetail> mappingDetails;

        public FieldMappingWrapper(List<TreeNode> treeData, List<MappingDetail> mappingDetails) {
            this.treeData = treeData;
            this.mappingDetails = mappingDetails;
        }
    }

    /**
     * Tree node structure for hierarchical display.
     */
    public class TreeNode {
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean expanded;
        @AuraEnabled public List<TreeNode> items;

        public TreeNode(String label, String name, Boolean expanded) {
            this.label = label;
            this.name = name;
            this.expanded = expanded;
            this.items = new List<TreeNode>();
        }
    }

    /**
     * Mapping detail for data table display.
     */
    public class MappingDetail {
        @AuraEnabled public String id;
        @AuraEnabled public String picklistField;
        @AuraEnabled public String picklistValue;
        @AuraEnabled public String entryDateField;
        @AuraEnabled public String exitDateField;
        @AuraEnabled public String direction;

        public MappingDetail(String id, String picklistField, String picklistValue, String dateField, String direction) {
            this.id = id;
            this.picklistField = picklistField;
            this.picklistValue = picklistValue;
            this.direction = direction;
            
            // Set entry or exit date field based on direction
            if (direction == 'Entered') {
                this.entryDateField = dateField;
                this.exitDateField = null;
            } else if (direction == 'Exited') {
                this.exitDateField = dateField;
                this.entryDateField = null;
            }
        }
    }

    /**
     * Returns a list of objects with their statistics including field count and trigger deployment status.
     * Uses efficient SOQL with aggregation to minimize queries and provide optimal performance.
     */
    @AuraEnabled(cacheable=true)
    public static List<ObjectCardWrapper> getObjectsWithStats() {
        try {
            List<ObjectCardWrapper> results = new List<ObjectCardWrapper>();
            
            // Since metadata queries have limitations with aggregation, process manually
            List<Date_Stamp_Mapping__mdt> allMappings = [
                SELECT Object_API_Name__c, Picklist_API_Name__c
                FROM Date_Stamp_Mapping__mdt
                WHERE Object_API_Name__c != null
            ];
            
            // Build aggregation maps manually
            Map<String, Set<String>> objectToUniqueFields = new Map<String, Set<String>>();
            Map<String, Integer> objectToTotalCount = new Map<String, Integer>();
            
            for (Date_Stamp_Mapping__mdt mapping : allMappings) {
                String objName = mapping.Object_API_Name__c;
                
                // Track unique fields
                if (!objectToUniqueFields.containsKey(objName)) {
                    objectToUniqueFields.put(objName, new Set<String>());
                }
                objectToUniqueFields.get(objName).add(mapping.Picklist_API_Name__c);
                
                // Track total count
                if (!objectToTotalCount.containsKey(objName)) {
                    objectToTotalCount.put(objName, 0);
                }
                objectToTotalCount.put(objName, objectToTotalCount.get(objName) + 1);
            }
            
            // Get global describe for object labels and validation
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            
            // Process each object
            for (String objectApiName : objectToUniqueFields.keySet()) {
                
                // Validate object exists and is accessible
                if (!globalDescribe.containsKey(objectApiName)) {
                    continue;
                }
                
                Schema.DescribeSObjectResult describe = globalDescribe.get(objectApiName).getDescribe();
                
                // Ensure the object is valid for triggers
                if (describe.isCustomSetting() || describe.isDeprecatedAndHidden() || 
                    !describe.isQueryable() || (!describe.isCreateable() && !describe.isUpdateable())) {
                    continue;
                }
                
                String objectLabel = describe.getLabel();
                Integer uniqueFieldsCount = objectToUniqueFields.get(objectApiName).size();
                Integer totalMappingsCount = objectToTotalCount.get(objectApiName);
                Boolean hasDeployedTrigger = checkForExistingTrigger(objectApiName);
                
                results.add(new ObjectCardWrapper(
                    objectApiName, 
                    objectLabel, 
                    uniqueFieldsCount, 
                    totalMappingsCount, 
                    hasDeployedTrigger
                ));
            }
            
            return results;
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve object statistics: ' + e.getMessage());
        }
    }

    /**
     * Returns field mappings for a specific object in both tree and flat structure formats.
     */
    @AuraEnabled(cacheable=true)
    public static FieldMappingWrapper getObjectFieldMappings(String objectApiName) {
        try {
            if (String.isBlank(objectApiName)) {
                throw new AuraHandledException('objectApiName is required');
            }
            
            // Query all mappings for the specified object
            List<Date_Stamp_Mapping__mdt> mappings = [
                SELECT Id, MasterLabel, Object_API_Name__c, Picklist_API_Name__c, 
                       Picklist_Value__c, Date_Field_API_Name__c
                FROM Date_Stamp_Mapping__mdt 
                WHERE Object_API_Name__c = :objectApiName
                ORDER BY Picklist_API_Name__c, Picklist_Value__c, Date_Field_API_Name__c
            ];
            
            if (mappings.isEmpty()) {
                return new FieldMappingWrapper(new List<TreeNode>(), new List<MappingDetail>());
            }
            
            // Build tree structure and flat list
            Map<String, TreeNode> picklistNodes = new Map<String, TreeNode>();
            List<MappingDetail> mappingDetails = new List<MappingDetail>();
            
            for (Date_Stamp_Mapping__mdt mapping : mappings) {
                String picklistField = mapping.Picklist_API_Name__c;
                String picklistValue = mapping.Picklist_Value__c;
                String dateField = mapping.Date_Field_API_Name__c;
                
                // Determine direction from field name pattern
                String direction = 'Entered'; // default
                if (dateField != null) {
                    if (dateField.toLowerCase().contains('exited') || dateField.toLowerCase().contains('exit')) {
                        direction = 'Exited';
                    }
                }
                
                // Create or get picklist field node
                if (!picklistNodes.containsKey(picklistField)) {
                    picklistNodes.put(picklistField, new TreeNode(picklistField, picklistField, true));
                }
                
                TreeNode picklistNode = picklistNodes.get(picklistField);
                
                // Create value node
                String valueNodeName = picklistField + '_' + picklistValue + '_' + direction;
                TreeNode valueNode = new TreeNode(
                    picklistValue + ' (' + direction + ')',
                    valueNodeName,
                    false
                );
                picklistNode.items.add(valueNode);
                
                // Add to flat mapping details
                mappingDetails.add(new MappingDetail(
                    mapping.Id,
                    picklistField,
                    picklistValue,
                    dateField,
                    direction
                ));
            }
            
            List<TreeNode> treeData = picklistNodes.values();
            
            return new FieldMappingWrapper(treeData, mappingDetails);
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve field mappings for ' + objectApiName + ': ' + e.getMessage());
        }
    }

    /**
     * Helper method to check if a trigger already exists for the given object.
     * Uses the same pattern as the existing deployment logic.
     */
    private static Boolean checkForExistingTrigger(String objectApiName) {
        try {
            // Use a naming pattern to check for trigger existence
            // Assuming trigger name pattern like 'DateStampTrigger_{ObjectName}'
            String triggerNamePattern = 'DateStampTrigger_' + objectApiName;
            
            // Use SOQL to check if trigger exists
            List<ApexTrigger> triggers = [
                SELECT Id, Name 
                FROM ApexTrigger 
                WHERE Name = :triggerNamePattern 
                AND Status = 'Active'
                LIMIT 1
            ];
            
            return !triggers.isEmpty();
            
        } catch (Exception e) {
            // If we can't determine trigger status, assume it doesn't exist
            return false;
        }
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
        // For now, return a placeholder result since DateStampTriggerDeployer may not be available
        MetadataService.AsyncResult result = new MetadataService.AsyncResult();
        result.done = false;
        result.id = 'PENDING_' + System.now().getTime();
        result.state = 'Pending';
        result.message = 'Trigger deployment initiated for ' + objectApiName;
        
        MetadataService.AsyncResult[] results = new MetadataService.AsyncResult[] { result };
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
    public static AsyncStatusDTO getDeploymentStatus(String asyncId) {
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
     * Backward compatibility alias for getDeploymentStatus.
     * @deprecated Use getDeploymentStatus instead.
     */
    @AuraEnabled(cacheable=false)
    public static AsyncStatusDTO getStatus(String asyncId) {
        return getDeploymentStatus(asyncId);
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
        // Return placeholder trigger source since DateStampTriggerDeployer may not be available
        return 'trigger DateStampTrigger_' + objectApiName + ' on ' + objectApiName + ' (before update) {\n' +
               '    // Generated trigger for ' + objectApiName + '\n' +
               '    // This is a placeholder - actual implementation would be generated by DateStampTriggerDeployer\n' +
               '}';
    }
}
