public with sharing class DateBuddyHandler {
    // Toggle to enable verbose debug logging (disabled by default for performance)
    @TestVisible
    private static Boolean LOG_DEBUG = false;
    // Test stub for injecting mock CMDT records
    @TestVisible
    private static List<Date_Stamp_Mapping__mdt> testMappings = null;
    
    // Static cache to prevent duplicate processing within the same transaction
    @TestVisible
    private static Set<String> processedRecordSignatures = new Set<String>();

    // Per-transaction caches to minimize repeated work
    @TestVisible
    private static Map<String, MappingConfig> CONFIG_CACHE = new Map<String, MappingConfig>();
    @TestVisible
    private static Map<String, Map<String, Schema.SObjectField>> FIELD_MAP_CACHE = new Map<String, Map<String, Schema.SObjectField>>();
    
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
        try {
            // Early exit for null/empty lists
            if (newList == null || newList.isEmpty()) return;

            String objectApiName = newList[0].getSObjectType().getDescribe().getName();

            // Build or reuse per-transaction caches for describe + mapping config
            Schema.SObjectType sType = newList[0].getSObjectType();
            Map<String, Schema.SObjectField> fieldMap = FIELD_MAP_CACHE.get(objectApiName);
            if (fieldMap == null) {
                fieldMap = sType.getDescribe().fields.getMap();
                FIELD_MAP_CACHE.put(objectApiName, fieldMap);
            }

            MappingConfig config = CONFIG_CACHE.get(objectApiName);
            if (config == null) {
                // Use test mappings if provided, otherwise query real CMDT
                List<Date_Stamp_Mapping__mdt> mappings;
                if (Test.isRunningTest() && testMappings != null) {
                    // Filter test mappings for the current object
                    mappings = new List<Date_Stamp_Mapping__mdt>();
                    for (Date_Stamp_Mapping__mdt m : testMappings) {
                        if (m.Object_API_Name__c == objectApiName) {
                            mappings.add(m);
                        }
                    }
                } else {
                    mappings = [
                        SELECT Object_API_Name__c, Picklist_API_Name__c, Picklist_Value__c,
                               Date_Field_API_Name__c, Exit_Date_Field_API_Name__c, Direction__c
                        FROM Date_Stamp_Mapping__mdt
                        WHERE Object_API_Name__c = :objectApiName
                    ];
                }

                // If no mappings, cache empty config and exit fast
                if (mappings.isEmpty()) {
                    CONFIG_CACHE.put(objectApiName, new MappingConfig());
                    return;
                }

                // Organize mappings by type for efficient processing
                config = new MappingConfig();
                for (Date_Stamp_Mapping__mdt m : mappings) {
                    try {
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
                    } catch (Exception e) {
                        // Log error but continue processing other mappings
                        if (LOG_DEBUG) System.debug('DateBuddyHandler: Error processing mapping - ' + e.getMessage());
                    }
                }
                CONFIG_CACHE.put(objectApiName, config);
            }

            Boolean isInsert = (oldMap == null || oldMap.isEmpty());

            // If no mappings for this object in this transaction, exit early
            Set<String> trackedFields = config.getAllPicklistFields();
            if (trackedFields.isEmpty()) {
                return;
            }

            // Process each record individually with error handling
            for (SObject rec : newList) {
                try {
                    SObject oldRec = isInsert ? null : oldMap.get(rec.Id);
                    
                    // Micro-optimization: on updates, if none of the tracked picklist fields changed,
                    // skip further processing for this record.
                    Map<String,String> newVals = new Map<String,String>();
                    Map<String,String> oldVals = new Map<String,String>();
                    // Precompute values once per record for tracked fields
                    for (String pickField : trackedFields) {
                        newVals.put(pickField, getFieldValueAsString(rec, pickField));
                        oldVals.put(pickField, isInsert ? null : getFieldValueAsString(oldRec, pickField));
                    }
                    if (!isInsert) {
                        Boolean anyTrackedChange = false;
                        for (String pickField : trackedFields) {
                            if (newVals.get(pickField) != oldVals.get(pickField)) {
                                anyTrackedChange = true;
                                break;
                            }
                        }
                        if (!anyTrackedChange) {
                            continue;
                        }
                    }
                    // Determine fields to evaluate for this record
                    Set<String> iterFields = new Set<String>();
                    if (isInsert) {
                        iterFields.addAll(trackedFields);
                    } else {
                        for (String f : trackedFields) {
                            if (newVals.get(f) != oldVals.get(f)) iterFields.add(f);
                        }
                    }

                    // Single pass: collect actions for signature + stamping, then stamp if not a duplicate
                    List<String> actionableTokens = new List<String>();
                    Set<String> dateFieldsToStamp = new Set<String>();
                    for (String pickField : iterFields) {
                        try {
                            String newValue = newVals.get(pickField);
                            String oldValue = isInsert ? null : oldVals.get(pickField);

                            // Entered
                            if (config.hasEnteredMapping(pickField, newValue)) {
                                if (isInsert || (oldValue != newValue)) {
                                    // Include old value in signature to distinguish repeated entries from different prior values
                                    String enterToken = 'ENTER:' + pickField + ':' + (isInsert ? newValue : (oldValue + '->' + newValue));
                                    actionableTokens.add(enterToken);
                                    String dateField = config.getEnteredDateField(pickField, newValue);
                                    try {
                                        if (rec.get(dateField) == null) {
                                            dateFieldsToStamp.add(dateField);
                                        }
                                    } catch (Exception e) {
                                        if (LOG_DEBUG) System.debug('DateBuddyHandler: Could not access entered date field ' + dateField + ' - ' + e.getMessage());
                                    }
                                }
                            }

                            // Exited (only on update)
                            if (!isInsert && config.hasExitedMapping(pickField, oldValue)) {
                                if (oldValue != newValue) {
                                    actionableTokens.add('EXIT:' + pickField + ':' + oldValue);
                                    String dateField = config.getExitedDateField(pickField, oldValue);
                                    try {
                                        if (rec.get(dateField) == null) {
                                            dateFieldsToStamp.add(dateField);
                                        }
                                    } catch (Exception e) {
                                        if (LOG_DEBUG) System.debug('DateBuddyHandler: Could not access exited date field ' + dateField + ' - ' + e.getMessage());
                                    }
                                }
                            }
                        } catch (Exception e) {
                            if (LOG_DEBUG) System.debug('DateBuddyHandler: Error processing field ' + pickField + ' - ' + e.getMessage());
                        }
                    }

                    // Build signature and perform dedupe
                    List<String> signatureParts = new List<String>{ objectApiName, String.valueOf(rec.Id) };
                    if (actionableTokens.isEmpty()) {
                        signatureParts.add('NO_ACTION');
                    } else {
                        signatureParts.addAll(actionableTokens);
                    }
                    String recordSignature = String.join(signatureParts, '|');
                    if (processedRecordSignatures.contains(recordSignature)) {
                        continue;
                    }
                    processedRecordSignatures.add(recordSignature);

                    // Stamp date fields
                    for (String df : dateFieldsToStamp) {
                        try {
                            if (rec.get(df) == null) {
                                rec.put(df, Date.today());
                            }
                        } catch (Exception e) {
                            if (LOG_DEBUG) System.debug('DateBuddyHandler: Could not set date field ' + df + ' - ' + e.getMessage());
                        }
                    }
                } catch (Exception e) {
                    // Log error but continue processing other records
                    if (LOG_DEBUG) System.debug('DateBuddyHandler: Error processing record - ' + e.getMessage());
                }
            }
        } catch (Exception e) {
            // Catch all to ensure we never block the transaction
            if (LOG_DEBUG) System.debug('DateBuddyHandler: Critical error in beforeInsertOrUpdate - ' + e.getMessage() + ' - Stack: ' + e.getStackTraceString());
            // Silently fail - DO NOT throw exception
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
    
    // Signature helper removed in favor of single-pass logic in beforeInsertOrUpdate
    
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
            //    - Otherwise map to enteredMappings (default)
            // 3. If only Exit field present: ALWAYS map to exitedMappings
            
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
                // Only Exit field present - ALWAYS map to exited
                addToMap(exitedMappings, mapping.Picklist_API_Name__c, mapping.Picklist_Value__c, mapping.Exit_Date_Field_API_Name__c);
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
