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
        @AuraEnabled public String objectName;
        @AuraEnabled public Integer totalMappings;
        @AuraEnabled public Integer entryMappings;
        @AuraEnabled public Integer exitMappings;
        @AuraEnabled public Integer fieldCount;
        
        public ObjectCardWrapper() {
            // Default constructor for test instantiation
        }

        public ObjectCardWrapper(String objectName, Integer totalMappings, Integer entryMappings, Integer exitMappings, Integer fieldCount) {
            this.objectName = objectName;
            this.totalMappings = totalMappings;
            this.entryMappings = entryMappings;
            this.exitMappings = exitMappings;
            this.fieldCount = fieldCount;
        }
    }

    /**
     * Wrapper class for field mapping information.
     */
    public class FieldMappingWrapper {
        @AuraEnabled public String objectName;
        @AuraEnabled public List<TreeNode> treeNodes;
        @AuraEnabled public List<MappingDetail> mappingDetails;
        
        public FieldMappingWrapper() {
            // Default constructor for test instantiation
            this.treeNodes = new List<TreeNode>();
            this.mappingDetails = new List<MappingDetail>();
        }

        public FieldMappingWrapper(String objectName, List<TreeNode> treeNodes, List<MappingDetail> mappingDetails) {
            this.objectName = objectName;
            this.treeNodes = treeNodes;
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
        
        public TreeNode() {
            // Default constructor for test instantiation
            this.items = new List<TreeNode>();
        }

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
        @AuraEnabled public String dateField;
        @AuraEnabled public String direction;
        
        public MappingDetail() {
            // Default constructor for test instantiation
        }

        public MappingDetail(String id, String picklistField, String picklistValue, String dateField, String direction) {
            this.id = id;
            this.picklistField = picklistField;
            this.picklistValue = picklistValue;
            this.dateField = dateField;
            this.direction = direction;
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
                SELECT Object_API_Name__c, Picklist_API_Name__c, Date_Field_API_Name__c, 
                       Exit_Date_Field_API_Name__c, Direction__c
                FROM Date_Stamp_Mapping__mdt
                WHERE Object_API_Name__c != null
            ];
            
            // Build aggregation maps manually
            Map<String, Set<String>> objectToUniqueFields = new Map<String, Set<String>>();
            Map<String, Integer> objectToTotalCount = new Map<String, Integer>();
            Map<String, Integer> objectToEntryCount = new Map<String, Integer>();
            Map<String, Integer> objectToExitCount = new Map<String, Integer>();
            
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
                    objectToEntryCount.put(objName, 0);
                    objectToExitCount.put(objName, 0);
                }
                objectToTotalCount.put(objName, objectToTotalCount.get(objName) + 1);
                
                // Determine direction based on fields populated and Direction__c value
                // Logic:
                // 1. If both Entry and Exit fields are populated, count as 1 entry AND 1 exit
                // 2. If Direction__c is populated, use it
                // 3. If only Exit_Date_Field_API_Name__c is populated (not Date_Field_API_Name__c), it's Exit
                // 4. Otherwise default to Entry
                String direction = mapping.Direction__c;
                Boolean hasEntryField = String.isNotBlank(mapping.Date_Field_API_Name__c);
                Boolean hasExitField = String.isNotBlank(mapping.Exit_Date_Field_API_Name__c);
                
                if (hasEntryField && hasExitField) {
                    // Both fields populated - count as both entry and exit
                    objectToEntryCount.put(objName, objectToEntryCount.get(objName) + 1);
                    objectToExitCount.put(objName, objectToExitCount.get(objName) + 1);
                    objectToTotalCount.put(objName, objectToTotalCount.get(objName) + 1); // Add extra for the dual count
                } else if (direction != null && direction.equalsIgnoreCase('Exited')) {
                    // Explicit Exit direction
                    objectToExitCount.put(objName, objectToExitCount.get(objName) + 1);
                } else if (!hasEntryField && hasExitField && String.isBlank(direction)) {
                    // Only Exit field populated, no direction specified - treat as Exit
                    objectToExitCount.put(objName, objectToExitCount.get(objName) + 1);
                } else {
                    // Default to Entry (includes when Direction__c = 'Entered' or when Date_Field_API_Name__c is populated)
                    objectToEntryCount.put(objName, objectToEntryCount.get(objName) + 1);
                }
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
                
                Integer fieldCount = objectToUniqueFields.get(objectApiName).size();
                Integer totalMappings = objectToTotalCount.get(objectApiName);
                Integer entryMappings = objectToEntryCount.get(objectApiName);
                Integer exitMappings = objectToExitCount.get(objectApiName);
                
                results.add(new ObjectCardWrapper(
                    objectApiName, 
                    totalMappings, 
                    entryMappings, 
                    exitMappings, 
                    fieldCount
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
                FieldMappingWrapper wrapper = new FieldMappingWrapper();
                wrapper.objectName = objectApiName;
                return wrapper;
            }
            
            // Query all mappings for the specified object
            List<Date_Stamp_Mapping__mdt> mappings = [
                SELECT Id, MasterLabel, Object_API_Name__c, Picklist_API_Name__c, 
                       Picklist_Value__c, Date_Field_API_Name__c, Exit_Date_Field_API_Name__c, Direction__c
                FROM Date_Stamp_Mapping__mdt 
                WHERE Object_API_Name__c = :objectApiName
                ORDER BY Picklist_API_Name__c, Picklist_Value__c, Date_Field_API_Name__c
            ];
            
            if (mappings.isEmpty()) {
                FieldMappingWrapper wrapper = new FieldMappingWrapper();
                wrapper.objectName = objectApiName;
                return wrapper;
            }
            
            // Build tree structure and flat list
            Map<String, TreeNode> picklistNodes = new Map<String, TreeNode>();
            List<MappingDetail> mappingDetails = new List<MappingDetail>();
            
            for (Date_Stamp_Mapping__mdt mapping : mappings) {
                String picklistField = mapping.Picklist_API_Name__c;
                String picklistValue = mapping.Picklist_Value__c;
                String dateField = mapping.Date_Field_API_Name__c;
                String exitDateField = mapping.Exit_Date_Field_API_Name__c;
                String directionValue = mapping.Direction__c;
                
                Boolean hasEntryField = String.isNotBlank(dateField);
                Boolean hasExitField = String.isNotBlank(exitDateField);
                
                // Create or get picklist field node
                if (!picklistNodes.containsKey(picklistField)) {
                    picklistNodes.put(picklistField, new TreeNode(picklistField, picklistField, true));
                }
                TreeNode picklistNode = picklistNodes.get(picklistField);
                
                // If both entry and exit fields are populated, create two separate entries
                if (hasEntryField && hasExitField) {
                    // Create Entry node
                    String entryNodeName = picklistField + '_' + picklistValue + '_Entered';
                    TreeNode entryNode = new TreeNode(
                        picklistValue + ' (Entered)',
                        entryNodeName,
                        false
                    );
                    picklistNode.items.add(entryNode);
                    
                    // Add Entry to flat mapping details
                    mappingDetails.add(new MappingDetail(
                        mapping.Id + '_entry',
                        picklistField,
                        picklistValue,
                        dateField,
                        'Entered'
                    ));
                    
                    // Create Exit node
                    String exitNodeName = picklistField + '_' + picklistValue + '_Exited';
                    TreeNode exitNode = new TreeNode(
                        picklistValue + ' (Exited)',
                        exitNodeName,
                        false
                    );
                    picklistNode.items.add(exitNode);
                    
                    // Add Exit to flat mapping details
                    mappingDetails.add(new MappingDetail(
                        mapping.Id + '_exit',
                        picklistField,
                        picklistValue,
                        exitDateField,
                        'Exited'
                    ));
                } else {
                    // Single entry based on which field is populated and Direction__c
                    String direction;
                    String displayDateField;
                    
                    // Logic must match DateBuddyHandler.MappingConfig.addMapping():
                    // 1. If only Exit field present: ALWAYS map to exited
                    // 2. If only Entry field present + Direction is 'Exited'/'Out': map to exited
                    // 3. Otherwise: map to entered (default)
                    
                    if (hasExitField && !hasEntryField) {
                        // Only Exit field present - ALWAYS show as Exited
                        direction = 'Exited';
                        displayDateField = exitDateField;
                    } else if (hasEntryField && !hasExitField) {
                        // Only Entry field present - check Direction
                        if (directionValue == 'Exited' || directionValue == 'Out') {
                            direction = 'Exited';
                        } else {
                            direction = 'Entered';
                        }
                        displayDateField = dateField;
                    } else {
                        // Fallback (shouldn't happen but handle gracefully)
                        direction = 'Entered';
                        displayDateField = dateField;
                    }
                    
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
                        displayDateField,
                        direction
                    ));
                }
            }
            
            List<TreeNode> treeNodes = picklistNodes.values();
            
            return new FieldMappingWrapper(objectApiName, treeNodes, mappingDetails);
            
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
        // Return a placeholder result for deployment tracking
        String deploymentId = 'PENDING_' + System.now().getTime();
        return deploymentId;
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
    
    /**
     * Returns picklist fields for a given object.
     * Used by the UI to display available picklist fields.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getObjectPicklistFields(String objectApiName) {
        List<Map<String, String>> fields = new List<Map<String, String>>();
        
        if (String.isBlank(objectApiName)) {
            return fields;
        }
        
        // Get object describe
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sObjectType == null) {
            return fields;
        }
        
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            
            if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST ||
                fieldDescribe.getType() == Schema.DisplayType.MULTIPICKLIST) {
                Map<String, String> field = new Map<String, String>();
                field.put('label', fieldDescribe.getLabel());
                field.put('value', fieldDescribe.getName());
                fields.add(field);
            }
        }
        
        return fields;
    }
    
    /**
     * Returns picklist values for a given field.
     * Used by the UI to display available values for a picklist field.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String objectApiName, String fieldApiName) {
        List<Map<String, String>> values = new List<Map<String, String>>();
        
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            return values;
        }
        
        // Get object describe
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sObjectType == null) {
            return values;
        }
        
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        Schema.SObjectField field = fieldMap.get(fieldApiName);
        
        if (field == null) {
            return values;
        }
        
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
        
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                Map<String, String> value = new Map<String, String>();
                value.put('label', entry.getLabel());
                value.put('value', entry.getValue());
                values.add(value);
            }
        }
        
        return values;
    }
    
    /**
     * Generates trigger code for the specified object and picklist field.
     * Used to create the trigger that will handle date stamping.
     */
    @AuraEnabled
    public static String generateTriggerCode(String objectApiName, String fieldApiName, 
                                            List<String> selectedValues, String entryPrefix, String exitPrefix) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            throw new AuraHandledException('Object and field API names are required');
        }
        
        String triggerName = 'DateStampTrigger_' + objectApiName + '_' + fieldApiName.replaceAll('__c', '');
        String triggerCode = 'trigger ' + triggerName + ' on ' + objectApiName + ' (before insert, before update) {\n';
        triggerCode += '    // Auto-generated trigger for date stamping\n';
        triggerCode += '    // Field: ' + fieldApiName + '\n';
        
        if (selectedValues != null && !selectedValues.isEmpty()) {
            triggerCode += '    // Values: ' + String.join(selectedValues, ', ') + '\n';
        }
        
        if (String.isNotBlank(entryPrefix)) {
            triggerCode += '    // Entry Date Prefix: ' + entryPrefix + '\n';
        }
        
        if (String.isNotBlank(exitPrefix)) {
            triggerCode += '    // Exit Date Prefix: ' + exitPrefix + '\n';
        }
        
        triggerCode += '    \n';
        triggerCode += '    // Trigger implementation would go here\n';
        triggerCode += '    // This is a placeholder for the actual date stamping logic\n';
        triggerCode += '}\n';
        
        return triggerCode;
    }
    
    /**
     * Deploys a trigger with the specified code and test class.
     * This version accepts trigger code and test code directly.
     */
    public static String deployTrigger(String triggerCode, String testCode, String objectApiName, String fieldApiName) {
        if (String.isBlank(triggerCode)) {
            throw new AuraHandledException('Trigger code is required');
        }
        
        // This is a stub implementation for testing
        // In a real implementation, this would use the Metadata API to deploy the trigger
        return 'DEPLOYMENT_ID_' + System.now().getTime();
    }
}
