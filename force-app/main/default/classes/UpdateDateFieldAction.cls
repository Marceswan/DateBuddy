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
        for (UpdateDateFieldRequest request : requests) {
            List<Date_Stamp_Mapping__mdt> mappings;
            // If a direction is provided, add it to the query criteria.
            if (String.isNotBlank(request.direction)) {
                mappings = [SELECT Date_Field_API_Name__c, Direction__c 
                            FROM Date_Stamp_Mapping__mdt 
                            WHERE Object_API_Name__c = :request.objectApiName 
                              AND Picklist_API_Name__c = :request.picklistApiName 
                              AND Picklist_Value__c = :request.picklistValue
                              AND Direction__c = :request.direction];
            } else {
                mappings = [SELECT Date_Field_API_Name__c, Direction__c 
                            FROM Date_Stamp_Mapping__mdt 
                            WHERE Object_API_Name__c = :request.objectApiName 
                              AND Picklist_API_Name__c = :request.picklistApiName 
                              AND Picklist_Value__c = :request.picklistValue];
            }
            if (!mappings.isEmpty()) {
                String dateFieldApiName = mappings[0].Date_Field_API_Name__c;
                Id recordId = request.recordId; // store the record Id separately
                SObject record = Database.query('SELECT ' + dateFieldApiName + ' FROM ' + request.objectApiName + ' WHERE Id = :recordId');
                if (record.get(dateFieldApiName) == null) {
                    record.put(dateFieldApiName, Date.today());
                    update record;
                }
            }
        }
    }
}