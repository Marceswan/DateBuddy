public class UpdateDateFieldAction {
    public class UpdateDateFieldRequest {
        @InvocableVariable(label='Object API Name' required=true)
        public String objectApiName;

        @InvocableVariable(label='Picklist API Name' required=true)
        public String picklistApiName;

        @InvocableVariable(label='Picklist Value' required=true)
        public String picklistValue;
        
        // New optional field for direction (picklist values: Enter, Exit)
        @InvocableVariable(label='Direction (Optional)')
        public String direction;

        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
    }

    @InvocableMethod(label='Update Date Field' description='Updates a date field in a record if it is NULL or blank.')
    public static void updateDateField(List<UpdateDateFieldRequest> requests) {
        if (requests == null || requests.isEmpty()) return;
        
        // Group requests by object type for batch processing
        Map<String, List<Id>> recordIdsByObject = new Map<String, List<Id>>();
        Map<Id, UpdateDateFieldRequest> requestById = new Map<Id, UpdateDateFieldRequest>();
        
        for (UpdateDateFieldRequest request : requests) {
            if (!recordIdsByObject.containsKey(request.objectApiName)) {
                recordIdsByObject.put(request.objectApiName, new List<Id>());
            }
            recordIdsByObject.get(request.objectApiName).add(request.recordId);
            requestById.put(request.recordId, request);
        }
        
        // Process each object type
        for (String objectApiName : recordIdsByObject.keySet()) {
            List<Id> recordIds = recordIdsByObject.get(objectApiName);
            
            // Query all fields needed for DateBuddyHandler
            Set<String> fieldsToQuery = new Set<String>{'Id'};
            
            // Get all picklist fields referenced in requests for this object
            Set<String> picklistFields = new Set<String>();
            for (Id recordId : recordIds) {
                UpdateDateFieldRequest req = requestById.get(recordId);
                picklistFields.add(req.picklistApiName);
            }
            fieldsToQuery.addAll(picklistFields);
            
            // Get all date fields from CMDT for this object
            List<Date_Stamp_Mapping__mdt> mappings = [
                SELECT Date_Field_API_Name__c, Exit_Date_Field_API_Name__c
                FROM Date_Stamp_Mapping__mdt
                WHERE Object_API_Name__c = :objectApiName
            ];
            
            for (Date_Stamp_Mapping__mdt mapping : mappings) {
                if (String.isNotBlank(mapping.Date_Field_API_Name__c)) {
                    fieldsToQuery.add(mapping.Date_Field_API_Name__c);
                }
                if (String.isNotBlank(mapping.Exit_Date_Field_API_Name__c)) {
                    fieldsToQuery.add(mapping.Exit_Date_Field_API_Name__c);
                }
            }
            
            // For Opportunity, always include CloseDate since it might be used by DateBuddyHandler
            if (objectApiName == 'Opportunity') {
                fieldsToQuery.add('CloseDate');
            }
            
            // Build and execute query
            String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + 
                          ' FROM ' + objectApiName + 
                          ' WHERE Id IN :recordIds';
            
            List<SObject> records = Database.query(query);
            
            // Create old map by simulating the picklist value as different
            Map<Id, SObject> oldMap = new Map<Id, SObject>();
            for (SObject record : records) {
                UpdateDateFieldRequest req = requestById.get(record.Id);
                
                // Clone the record for the old map
                SObject oldRecord = record.clone(true, true, true, true);
                
                // Set the old picklist value to something different to trigger the handler
                // This simulates the field changing TO the target value
                String currentValue = String.valueOf(record.get(req.picklistApiName));
                if (currentValue == req.picklistValue) {
                    // Already has the value, set old to different value to simulate entering
                    oldRecord.put(req.picklistApiName, 'DIFFERENT_VALUE_FOR_TRIGGER');
                } else {
                    // Doesn't have the value yet, set current to target value
                    record.put(req.picklistApiName, req.picklistValue);
                    oldRecord.put(req.picklistApiName, currentValue);
                }
                
                oldMap.put(record.Id, oldRecord);
            }
            
            // Call DateBuddyHandler to process the records
            DateBuddyHandler.beforeInsertOrUpdate(records, oldMap);
            
            // Update the records
            update records;
        }
    }
}
