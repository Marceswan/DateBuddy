public with sharing class DateBuddyHandler {
    /**
     * Generic before-save handler that sets date fields based on CMDT mappings.
     * Handles both "Entered" (when value changes TO the target value) and 
     * "Exited" (when value changes FROM the target value) scenarios.
     *
     * Expects Date_Stamp_Mapping__mdt fields:
     * - Object_API_Name__c
     * - Picklist_API_Name__c
     * - Picklist_Value__c
     * - Date_Field_API_Name__c
     * - Direction__c (optional: 'Entered'/'In' or 'Exited'/'Out')
     */
    public static void beforeInsertOrUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        String objectApiName = newList[0].getSObjectType().getDescribe().getName();

        List<Date_Stamp_Mapping__mdt> mappings = [
            SELECT Object_API_Name__c, Picklist_API_Name__c, Picklist_Value__c, 
                   Date_Field_API_Name__c, Direction__c
            FROM Date_Stamp_Mapping__mdt
            WHERE Object_API_Name__c = :objectApiName
        ];
        if (mappings.isEmpty()) return;

        Schema.SObjectType sType = newList[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();

        // Organize mappings by type for efficient processing
        MappingConfig config = new MappingConfig();
        for (Date_Stamp_Mapping__mdt m : mappings) {
            if (!fieldMap.containsKey(m.Picklist_API_Name__c) || !fieldMap.containsKey(m.Date_Field_API_Name__c)) {
                continue; // skip invalid field references
            }
            config.addMapping(m);
        }

        Boolean isInsert = (oldMap == null || oldMap.isEmpty());

        for (SObject rec : newList) {
            SObject oldRec = isInsert ? null : oldMap.get(rec.Id);
            
            // Process all configured picklist fields
            for (String pickField : config.getAllPicklistFields()) {
                String newValue = getFieldValueAsString(rec, pickField);
                String oldValue = isInsert ? null : getFieldValueAsString(oldRec, pickField);
                
                // Check for "Entered" conditions
                if (config.hasEnteredMapping(pickField, newValue)) {
                    if (isInsert || (oldValue != newValue)) {
                        // Value changed TO the target value (or new record with target value)
                        String dateField = config.getEnteredDateField(pickField, newValue);
                        if (rec.get(dateField) == null) {
                            rec.put(dateField, Date.today());
                        }
                    }
                }
                
                // Check for "Exited" conditions (only on updates)
                if (!isInsert && config.hasExitedMapping(pickField, oldValue)) {
                    if (oldValue != newValue) {
                        // Value changed FROM the target value
                        String dateField = config.getExitedDateField(pickField, oldValue);
                        if (rec.get(dateField) == null) {
                            rec.put(dateField, Date.today());
                        }
                    }
                }
                
                // Handle legacy mappings without Direction specified (backward compatibility)
                if (config.hasLegacyMapping(pickField, newValue)) {
                    String dateField = config.getLegacyDateField(pickField, newValue);
                    if (rec.get(dateField) == null) {
                        rec.put(dateField, Date.today());
                    }
                }
            }
        }
    }
    
    private static String getFieldValueAsString(SObject rec, String fieldName) {
        if (rec == null) return null;
        try {
            Object val = rec.get(fieldName);
            return val == null ? null : String.valueOf(val);
        } catch (Exception e) {
            return null;
        }
    }
    
    /**
     * Inner class to organize and efficiently access mapping configurations
     */
    private class MappingConfig {
        // Maps for "Entered" direction: picklistField -> (value -> dateField)
        private Map<String, Map<String, String>> enteredMappings = new Map<String, Map<String, String>>();
        
        // Maps for "Exited" direction: picklistField -> (value -> dateField)
        private Map<String, Map<String, String>> exitedMappings = new Map<String, Map<String, String>>();
        
        // Maps for legacy (no direction) mappings: picklistField -> (value -> dateField)
        private Map<String, Map<String, String>> legacyMappings = new Map<String, Map<String, String>>();
        
        public void addMapping(Date_Stamp_Mapping__mdt mapping) {
            String direction = mapping.Direction__c;
            Map<String, Map<String, String>> targetMap;
            
            // Support both 'Entered'/'In' and 'Exited'/'Out' values
            if (direction == 'Entered' || direction == 'In') {
                targetMap = enteredMappings;
            } else if (direction == 'Exited' || direction == 'Out') {
                targetMap = exitedMappings;
            } else {
                // No direction specified - legacy behavior
                targetMap = legacyMappings;
            }
            
            if (!targetMap.containsKey(mapping.Picklist_API_Name__c)) {
                targetMap.put(mapping.Picklist_API_Name__c, new Map<String, String>());
            }
            targetMap.get(mapping.Picklist_API_Name__c).put(
                mapping.Picklist_Value__c, 
                mapping.Date_Field_API_Name__c
            );
        }
        
        public Set<String> getAllPicklistFields() {
            Set<String> allFields = new Set<String>();
            allFields.addAll(enteredMappings.keySet());
            allFields.addAll(exitedMappings.keySet());
            allFields.addAll(legacyMappings.keySet());
            return allFields;
        }
        
        public Boolean hasEnteredMapping(String pickField, String value) {
            return enteredMappings.containsKey(pickField) && 
                   value != null &&
                   enteredMappings.get(pickField).containsKey(value);
        }
        
        public String getEnteredDateField(String pickField, String value) {
            return enteredMappings.get(pickField).get(value);
        }
        
        public Boolean hasExitedMapping(String pickField, String value) {
            return exitedMappings.containsKey(pickField) && 
                   value != null &&
                   exitedMappings.get(pickField).containsKey(value);
        }
        
        public String getExitedDateField(String pickField, String value) {
            return exitedMappings.get(pickField).get(value);
        }
        
        public Boolean hasLegacyMapping(String pickField, String value) {
            return legacyMappings.containsKey(pickField) && 
                   value != null &&
                   legacyMappings.get(pickField).containsKey(value);
        }
        
        public String getLegacyDateField(String pickField, String value) {
            return legacyMappings.get(pickField).get(value);
        }
    }
}
