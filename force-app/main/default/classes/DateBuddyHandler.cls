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
     * - Date_Field_API_Name__c - Date field to stamp on entry (optional)
     * - Exit_Date_Field_API_Name__c - Date field to stamp on exit (optional)
     * - Direction__c (optional: 'Entered'/'In' or 'Exited'/'Out' - used when only one date field is populated)
     */
    public static void beforeInsertOrUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        String objectApiName = newList[0].getSObjectType().getDescribe().getName();

        List<Date_Stamp_Mapping__mdt> mappings = [
            SELECT Object_API_Name__c, Picklist_API_Name__c, Picklist_Value__c, 
                   Date_Field_API_Name__c, Exit_Date_Field_API_Name__c, Direction__c
            FROM Date_Stamp_Mapping__mdt
            WHERE Object_API_Name__c = :objectApiName
        ];
        if (mappings.isEmpty()) return;

        Schema.SObjectType sType = newList[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();

        // Organize mappings by type for efficient processing
        MappingConfig config = new MappingConfig();
        for (Date_Stamp_Mapping__mdt m : mappings) {
            // Validate picklist field exists
            if (!fieldMap.containsKey(m.Picklist_API_Name__c)) {
                continue;
            }
            // Validate at least one date field exists and is valid
            Boolean hasValidEntryField = m.Date_Field_API_Name__c != null && fieldMap.containsKey(m.Date_Field_API_Name__c);
            Boolean hasValidExitField = m.Exit_Date_Field_API_Name__c != null && fieldMap.containsKey(m.Exit_Date_Field_API_Name__c);
            if (!hasValidEntryField && !hasValidExitField) {
                continue; // skip if neither date field is valid
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
        
        public void addMapping(Date_Stamp_Mapping__mdt mapping) {
            String direction = mapping.Direction__c;
            Boolean hasEntryField = mapping.Date_Field_API_Name__c != null;
            Boolean hasExitField = mapping.Exit_Date_Field_API_Name__c != null;
            
            // Logic for determining which mappings to create:
            // 1. If both fields present, map Entry to enteredMappings and Exit to exitedMappings
            // 2. If only Entry field present:
            //    - If Direction is 'Exited'/'Out', map to exitedMappings
            //    - Otherwise map to enteredMappings
            // 3. If only Exit field present:
            //    - If Direction is 'Entered'/'In', map to enteredMappings  
            //    - Otherwise map to exitedMappings
            
            if (hasEntryField && hasExitField) {
                // Both fields present - map Entry to entered, Exit to exited
                addToMap(enteredMappings, mapping.Picklist_API_Name__c, mapping.Picklist_Value__c, mapping.Date_Field_API_Name__c);
                addToMap(exitedMappings, mapping.Picklist_API_Name__c, mapping.Picklist_Value__c, mapping.Exit_Date_Field_API_Name__c);
            } else if (hasEntryField) {
                // Only Entry field present - check Direction
                if (direction == 'Exited' || direction == 'Out') {
                    addToMap(exitedMappings, mapping.Picklist_API_Name__c, mapping.Picklist_Value__c, mapping.Date_Field_API_Name__c);
                } else {
                    // Default to entered for Entry field (includes null Direction)
                    addToMap(enteredMappings, mapping.Picklist_API_Name__c, mapping.Picklist_Value__c, mapping.Date_Field_API_Name__c);
                }
            } else if (hasExitField) {
                // Only Exit field present - check Direction
                if (direction == 'Entered' || direction == 'In') {
                    addToMap(enteredMappings, mapping.Picklist_API_Name__c, mapping.Picklist_Value__c, mapping.Exit_Date_Field_API_Name__c);
                } else {
                    // Default to exited for Exit field (includes null Direction)
                    addToMap(exitedMappings, mapping.Picklist_API_Name__c, mapping.Picklist_Value__c, mapping.Exit_Date_Field_API_Name__c);
                }
            }
        }
        
        private void addToMap(Map<String, Map<String, String>> targetMap, String picklistField, String picklistValue, String dateField) {
            if (!targetMap.containsKey(picklistField)) {
                targetMap.put(picklistField, new Map<String, String>());
            }
            targetMap.get(picklistField).put(picklistValue, dateField);
        }
        
        public Set<String> getAllPicklistFields() {
            Set<String> allFields = new Set<String>();
            allFields.addAll(enteredMappings.keySet());
            allFields.addAll(exitedMappings.keySet());
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
    }
}
