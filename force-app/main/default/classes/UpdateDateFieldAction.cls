public class UpdateDateFieldAction {
    public class UpdateDateFieldRequest {
        @InvocableVariable(label='Object API Name' required=true)
        public String objectApiName;

        @InvocableVariable(label='Picklist API Name' required=true)
        public String picklistApiName;

        @InvocableVariable(label='Picklist Value' required=true)
        public String picklistValue;

        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
    }

    @InvocableMethod(label='Update Date Field' description='Updates a date field in a record if it is NULL or blank.')
    public static void updateDateField(List<UpdateDateFieldRequest> requests) {
        for (UpdateDateFieldRequest request : requests) {
            List<Date_Stamp_Mapping__mdt> mappings = [SELECT Date_Field_API_Name__c FROM Date_Stamp_Mapping__mdt WHERE Object_API_Name__c = :request.objectApiName AND Picklist_API_Name__c = :request.picklistApiName AND Picklist_Value__c = :request.picklistValue];
            if (!mappings.isEmpty()) {
                String dateFieldApiName = mappings[0].Date_Field_API_Name__c;
                Id recordId = request.recordId; // Store the record Id in a separate variable
                SObject record = Database.query('SELECT ' + dateFieldApiName + ' FROM ' + request.objectApiName + ' WHERE Id = :recordId'); // Use the separate variable in the query
                if (record.get(dateFieldApiName) == null) {
                    record.put(dateFieldApiName, Date.today());
                    update record;
                }
            }
        }
    }
}
