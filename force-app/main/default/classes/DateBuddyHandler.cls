public with sharing class DateBuddyHandler {
    /**
     * Generic before-save handler that sets a date field based on CMDT mappings
     * when a given picklist field equals a mapped value and the date field is null.
     *
     * Expects Date_Stamp_Mapping__mdt fields:
     * - Object_API_Name__c
     * - Picklist_API_Name__c
     * - Picklist_Value__c
     * - Date_Field_API_Name__c
     */
    public static void beforeInsertOrUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        String objectApiName = newList[0].getSObjectType().getDescribe().getName();

        List<Date_Stamp_Mapping__mdt> mappings = [
            SELECT Object_API_Name__c, Picklist_API_Name__c, Picklist_Value__c, Date_Field_API_Name__c
            FROM Date_Stamp_Mapping__mdt
            WHERE Object_API_Name__c = :objectApiName
        ];
        if (mappings.isEmpty()) return;

        Schema.SObjectType sType = newList[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();

        // Map of picklist field -> (value -> date field)
        Map<String, Map<String, String>> config = new Map<String, Map<String, String>>();
        for (Date_Stamp_Mapping__mdt m : mappings) {
            if (!fieldMap.containsKey(m.Picklist_API_Name__c) || !fieldMap.containsKey(m.Date_Field_API_Name__c)) {
                continue; // skip invalid field references for this object
            }
            if (!config.containsKey(m.Picklist_API_Name__c)) {
                config.put(m.Picklist_API_Name__c, new Map<String, String>());
            }
            config.get(m.Picklist_API_Name__c).put(m.Picklist_Value__c, m.Date_Field_API_Name__c);
        }
        if (config.isEmpty()) return;

        for (SObject rec : newList) {
            for (String pickField : config.keySet()) {
                Map<String, String> valueToDateField = config.get(pickField);
                Object pickVal;
                try {
                    pickVal = rec.get(pickField);
                } catch (Exception e) {
                    continue;
                }
                if (pickVal == null) continue;
                String key = String.valueOf(pickVal);
                if (!valueToDateField.containsKey(key)) continue;

                String dateField = valueToDateField.get(key);
                if (rec.get(dateField) == null) {
                    rec.put(dateField, Date.today());
                }
            }
        }
    }
}
