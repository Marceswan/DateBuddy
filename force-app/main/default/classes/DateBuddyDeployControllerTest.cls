@IsTest(seeAllData=false)
public class DateBuddyDeployControllerTest {
    @IsTest
    static void testGetStatus_returnsCompleted() {
        DateBuddyDeployController.AsyncStatusDTO dto = DateBuddyDeployController.getStatus('abc123');
        System.assertEquals('abc123', dto.id);
        System.assertEquals(true, dto.done);
        System.assertEquals('Completed', dto.state);
        System.assertEquals('Trigger deployed successfully', dto.message);
    }

    @IsTest
    static void testDeployTrigger_blankObjectNameThrows() {
        try {
            DateBuddyDeployController.deployTrigger('');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('objectApiName is required'));
        }
    }

    @IsTest
    static void testGetTriggerSource_mirrorsGenerator() {
        String expectedName = DateStampTriggerDeployer.generateTriggerName('Task');
        String fromController = DateBuddyDeployController.getTriggerSource('Task');
        System.assert(fromController.contains('trigger ' + expectedName), 'Should contain generated trigger name');
        System.assert(fromController.contains('on Task (before insert, before update)'));
        System.assert(fromController.contains('DateBuddyHandler.beforeInsertOrUpdate'));
    }

    @IsTest
    static void testListSObjects_containsCoreObject() {
        List<String> names = DateBuddyDeployController.listSObjects();
        System.assert(!names.isEmpty(), 'Should return some SObject names');
        System.assert(names.contains('Task') || names.contains('Account'), 'Should include common SObjects');
    }
    
    @IsTest
    static void testGetObjectsWithStats() {
        Test.startTest();
        List<DateBuddyDeployController.ObjectCardWrapper> result = 
            DateBuddyDeployController.getObjectsWithStats();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return at least one object');
        
        Boolean hasContact = false;
        for (DateBuddyDeployController.ObjectCardWrapper wrapper : result) {
            if (wrapper.objectName == 'Contact') {
                hasContact = true;
                System.assertNotEquals(null, wrapper.totalMappings, 'Total mappings should not be null');
                System.assertNotEquals(null, wrapper.entryMappings, 'Entry mappings should not be null');
                System.assertNotEquals(null, wrapper.exitMappings, 'Exit mappings should not be null');
                System.assertNotEquals(null, wrapper.fieldCount, 'Field count should not be null');
                System.assert(wrapper.totalMappings >= 0, 'Total mappings should be non-negative');
                System.assert(wrapper.entryMappings >= 0, 'Entry mappings should be non-negative');
                System.assert(wrapper.exitMappings >= 0, 'Exit mappings should be non-negative');
                System.assert(wrapper.fieldCount >= 0, 'Field count should be non-negative');
            }
        }
        System.assert(hasContact, 'Contact object should be present in results');
    }
    
    @IsTest
    static void testGetObjectFieldMappings() {
        Test.startTest();
        DateBuddyDeployController.FieldMappingWrapper result = 
            DateBuddyDeployController.getObjectFieldMappings('Contact');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Contact', result.objectName, 'Object name should match');
        System.assertNotEquals(null, result.treeNodes, 'Tree nodes should not be null');
        System.assertNotEquals(null, result.mappingDetails, 'Mapping details should not be null');
    }
    
    @IsTest
    static void testGetObjectFieldMappingsWithData() {
        Test.startTest();
        DateBuddyDeployController.FieldMappingWrapper result = 
            DateBuddyDeployController.getObjectFieldMappings('Contact');
        Test.stopTest();
        
        if (!result.treeNodes.isEmpty()) {
            DateBuddyDeployController.TreeNode firstNode = result.treeNodes[0];
            System.assertNotEquals(null, firstNode.label, 'Tree node label should not be null');
            System.assertNotEquals(null, firstNode.name, 'Tree node name should not be null');
            System.assertNotEquals(null, firstNode.expanded, 'Tree node expanded should not be null');
            
            if (firstNode.items != null && !firstNode.items.isEmpty()) {
                DateBuddyDeployController.TreeNode childNode = firstNode.items[0];
                System.assertNotEquals(null, childNode.label, 'Child node label should not be null');
                System.assertNotEquals(null, childNode.name, 'Child node name should not be null');
            }
        }
        
        if (!result.mappingDetails.isEmpty()) {
            DateBuddyDeployController.MappingDetail firstMapping = result.mappingDetails[0];
            System.assertNotEquals(null, firstMapping.picklistField, 'Picklist field should not be null');
            System.assertNotEquals(null, firstMapping.picklistValue, 'Picklist value should not be null');
            System.assertNotEquals(null, firstMapping.direction, 'Direction should not be null');
            System.assertNotEquals(null, firstMapping.dateField, 'Date field should not be null');
        }
    }
    
    @IsTest
    static void testGetObjectFieldMappingsInvalidObject() {
        Test.startTest();
        DateBuddyDeployController.FieldMappingWrapper result = 
            DateBuddyDeployController.getObjectFieldMappings('InvalidObject');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null even for invalid object');
        System.assertEquals('InvalidObject', result.objectName, 'Object name should match input');
        System.assertNotEquals(null, result.treeNodes, 'Tree nodes should not be null');
        System.assertNotEquals(null, result.mappingDetails, 'Mapping details should not be null');
        System.assertEquals(0, result.mappingDetails.size(), 'Should have no mappings for invalid object');
    }
    
    @IsTest
    static void testGetObjectFieldMappingsNullObject() {
        Test.startTest();
        DateBuddyDeployController.FieldMappingWrapper result = 
            DateBuddyDeployController.getObjectFieldMappings(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should handle null gracefully');
        System.assertEquals(null, result.objectName, 'Object name should be null');
        System.assertNotEquals(null, result.treeNodes, 'Tree nodes should not be null');
        System.assertNotEquals(null, result.mappingDetails, 'Mapping details should not be null');
        System.assertEquals(0, result.treeNodes.size(), 'Should have no tree nodes for null object');
        System.assertEquals(0, result.mappingDetails.size(), 'Should have no mappings for null object');
    }
    
    @IsTest
    static void testCachingBehavior() {
        Test.startTest();
        List<DateBuddyDeployController.ObjectCardWrapper> result1 = 
            DateBuddyDeployController.getObjectsWithStats();
        
        List<DateBuddyDeployController.ObjectCardWrapper> result2 = 
            DateBuddyDeployController.getObjectsWithStats();
        Test.stopTest();
        
        System.assertEquals(result1.size(), result2.size(), 'Cached results should have same size');
        if (!result1.isEmpty() && !result2.isEmpty()) {
            System.assertEquals(result1[0].objectName, result2[0].objectName, 'Cached object names should match');
            System.assertEquals(result1[0].totalMappings, result2[0].totalMappings, 'Cached mappings should match');
        }
    }
    
    @IsTest
    static void testFieldMappingCaching() {
        Test.startTest();
        DateBuddyDeployController.FieldMappingWrapper result1 = 
            DateBuddyDeployController.getObjectFieldMappings('Contact');
        
        DateBuddyDeployController.FieldMappingWrapper result2 = 
            DateBuddyDeployController.getObjectFieldMappings('Contact');
        Test.stopTest();
        
        System.assertEquals(result1.objectName, result2.objectName, 'Cached object names should match');
        System.assertEquals(result1.treeNodes.size(), result2.treeNodes.size(), 'Cached tree nodes should match');
        System.assertEquals(result1.mappingDetails.size(), result2.mappingDetails.size(), 'Cached mappings should match');
    }
    
    @IsTest
    static void testWrapperClassInstantiation() {
        DateBuddyDeployController.ObjectCardWrapper cardWrapper = 
            new DateBuddyDeployController.ObjectCardWrapper();
        cardWrapper.objectName = 'TestObject';
        cardWrapper.totalMappings = 10;
        cardWrapper.entryMappings = 5;
        cardWrapper.exitMappings = 5;
        cardWrapper.fieldCount = 3;
        
        System.assertEquals('TestObject', cardWrapper.objectName);
        System.assertEquals(10, cardWrapper.totalMappings);
        System.assertEquals(5, cardWrapper.entryMappings);
        System.assertEquals(5, cardWrapper.exitMappings);
        System.assertEquals(3, cardWrapper.fieldCount);
        
        DateBuddyDeployController.FieldMappingWrapper fieldWrapper = 
            new DateBuddyDeployController.FieldMappingWrapper();
        fieldWrapper.objectName = 'TestObject';
        fieldWrapper.treeNodes = new List<DateBuddyDeployController.TreeNode>();
        fieldWrapper.mappingDetails = new List<DateBuddyDeployController.MappingDetail>();
        
        System.assertEquals('TestObject', fieldWrapper.objectName);
        System.assertNotEquals(null, fieldWrapper.treeNodes);
        System.assertNotEquals(null, fieldWrapper.mappingDetails);
        
        DateBuddyDeployController.TreeNode treeNode = 
            new DateBuddyDeployController.TreeNode();
        treeNode.label = 'Test Field';
        treeNode.name = 'Test_Field__c';
        treeNode.expanded = true;
        treeNode.items = new List<DateBuddyDeployController.TreeNode>();
        
        System.assertEquals('Test Field', treeNode.label);
        System.assertEquals('Test_Field__c', treeNode.name);
        System.assertEquals(true, treeNode.expanded);
        System.assertNotEquals(null, treeNode.items);
        
        DateBuddyDeployController.MappingDetail mappingDetail = 
            new DateBuddyDeployController.MappingDetail();
        mappingDetail.picklistField = 'Status__c';
        mappingDetail.picklistValue = 'Active';
        mappingDetail.direction = 'Entered';
        mappingDetail.dateField = 'Date_Entered_Active__c';
        
        System.assertEquals('Status__c', mappingDetail.picklistField);
        System.assertEquals('Active', mappingDetail.picklistValue);
        System.assertEquals('Entered', mappingDetail.direction);
        System.assertEquals('Date_Entered_Active__c', mappingDetail.dateField);
    }
    
    @IsTest
    static void testGetObjectPicklistFields() {
        Test.startTest();
        List<Map<String, String>> fields = DateBuddyDeployController.getObjectPicklistFields('Contact');
        Test.stopTest();
        
        System.assertNotEquals(null, fields, 'Fields list should not be null');
        System.assert(fields.size() > 0, 'Should return at least one picklist field');
        
        for(Map<String, String> field : fields) {
            System.assert(field.containsKey('label'), 'Field should have a label');
            System.assert(field.containsKey('value'), 'Field should have a value');
        }
    }
    
    @IsTest
    static void testGetPicklistValues() {
        Test.startTest();
        List<Map<String, String>> values = DateBuddyDeployController.getPicklistValues('Contact', 'LeadSource');
        Test.stopTest();
        
        System.assertNotEquals(null, values, 'Values list should not be null');
        
        for(Map<String, String> value : values) {
            System.assert(value.containsKey('label'), 'Value should have a label');
            System.assert(value.containsKey('value'), 'Value should have a value');
        }
    }
    
    @IsTest
    static void testGenerateTriggerCode() {
        List<String> selectedValues = new List<String>{'Web', 'Phone Inquiry'};
        
        Test.startTest();
        String triggerCode = DateBuddyDeployController.generateTriggerCode(
            'Contact', 
            'LeadSource',
            selectedValues,
            'Date_Entered_',
            'Date_Exited_'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, triggerCode, 'Trigger code should not be null');
        System.assert(triggerCode.contains('trigger'), 'Should contain trigger keyword');
        System.assert(triggerCode.contains('LeadSource'), 'Should contain field name');
        System.assert(triggerCode.contains('Date_Entered_'), 'Should contain entry prefix');
        System.assert(triggerCode.contains('Date_Exited_'), 'Should contain exit prefix');
    }
    
    @IsTest
    static void testDeployTrigger() {
        String mockTriggerCode = 'trigger TestTrigger on Contact (before update) { }';
        String mockTestCode = '@isTest class TestTriggerTest { }';
        
        Test.startTest();
        String result = DateBuddyDeployController.deployTrigger(
            mockTriggerCode,
            mockTestCode,
            'Contact',
            'TestField'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Deploy result should not be null');
    }
}

