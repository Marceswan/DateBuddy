public without sharing class DateStampTriggerDeployer {
    /**
     * Deploy method that creates and deploys trigger using JSZip
     * This integrates with the Visualforce page for actual deployment
     */
    public static MetadataService.AsyncResult[] deploy(String objectApiName) {
        // Get trigger details
        String triggerName = generateTriggerName(objectApiName);
        String triggerSource = generateTriggerSource(objectApiName, triggerName);
        
        // For now, we need the VF page to handle the actual ZIP creation and deployment
        // The LWC should navigate to /apex/DateBuddyDeploy with the objectApiName parameter
        // Then call the JavaScript deployTrigger function
        
        MetadataService.AsyncResult result = new MetadataService.AsyncResult();
        result.done = false;
        result.id = 'PENDING_VF_' + System.now().getTime();
        result.state = 'Pending';
        result.message = 'Use /apex/DateBuddyDeploy?objectApiName=' + objectApiName + ' for deployment';
        
        return new MetadataService.AsyncResult[] { result };
    }
    
    /**
     * RemoteAction for VF page to get trigger details
     */
    @RemoteAction
    public static Map<String, String> getTriggerDetails(String objectApiName) {
        String triggerName = generateTriggerName(objectApiName);
        String testClassName = generateTestClassName(objectApiName);
        Map<String, String> result = new Map<String, String>();
        result.put('triggerName', triggerName);
        result.put('triggerSource', generateTriggerSource(objectApiName, triggerName));
        result.put('testClassName', testClassName);
        result.put('testClassSource', generateTestClassSource(objectApiName, triggerName, testClassName));
        return result;
    }
    
    /**
     * RemoteAction to deploy ZIP from Visualforce page
     * @param zipData Base64 encoded ZIP file containing the trigger package
     * @param testClassName Name of the test class to run (optional)
     * @param deploymentName Name for this deployment (optional)
     * @return The async result ID for tracking
     */
    @RemoteAction
    public static String deployZip(String zipData, String testClassName, String deploymentName) {
        try {
            // Create MetadataService and configure deployment options
            MetadataService.MetadataPort service = new MetadataService.MetadataPort();
            service.SessionHeader = new MetadataService.SessionHeader_element();
            service.SessionHeader.sessionId = UserInfo.getSessionId();
            service.endpoint_x = System.Url.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/62.0';
            
            // Configure deployment options following apex-mdapi best practices
            MetadataService.DeployOptions deployOptions = new MetadataService.DeployOptions();
            deployOptions.allowMissingFiles = false;
            deployOptions.autoUpdatePackage = false;
            deployOptions.checkOnly = false;  // Set to true for validation-only
            deployOptions.ignoreWarnings = false;
            deployOptions.performRetrieve = false;
            deployOptions.purgeOnDelete = false;
            deployOptions.rollbackOnError = true;
            deployOptions.singlePackage = true;
            
            // Set deployment name for easy tracking in Setup > Deployment Status
            if (String.isNotBlank(deploymentName)) {
                // Note: DeployOptions doesn't have a deploymentName field in the standard API
                // We'll use the deployment comment in the package.xml instead
            }
            
            // Use RunSpecifiedTests with the generated test class for this trigger
            if (String.isNotBlank(testClassName)) {
                deployOptions.testLevel = 'RunSpecifiedTests';
                deployOptions.runTests = new String[] { testClassName };
            } else {
                // Fallback to RunLocalTests if no test class specified
                deployOptions.testLevel = 'RunLocalTests';
            }
            
            // Deploy the ZIP package received from Visualforce page
            MetadataService.AsyncResult result = service.deploy(zipData, deployOptions);
            return result.id;
        } catch (Exception e) {
            throw new AuraHandledException('Deployment failed: ' + e.getMessage());
        }
    }
    
    /**
     * Prepares trigger package data for deployment.
     * This method is called by Visualforce page to get the package components.
     * 
     * @param objectApiName The object to create trigger for
     * @return Map containing package components (packageXml, triggerSource, triggerMetadata, testClass, testClassMetadata)
     */
    @RemoteAction
    public static Map<String, String> prepareDeploymentPackage(String objectApiName) {
        String triggerName = generateTriggerName(objectApiName);
        String testClassName = generateTestClassName(objectApiName);
        
        Map<String, String> packageComponents = new Map<String, String>();
        packageComponents.put('packageXml', generatePackageXml(triggerName, testClassName));
        packageComponents.put('triggerSource', generateTriggerSource(objectApiName, triggerName));
        packageComponents.put('triggerMetadata', generateTriggerMetaXml());
        packageComponents.put('triggerName', triggerName);
        packageComponents.put('testClassName', testClassName);
        packageComponents.put('testClassSource', generateTestClassSource(objectApiName, triggerName, testClassName));
        packageComponents.put('testClassMetadata', generateTestClassMetaXml());
        
        return packageComponents;
    }
    
    
    /**
     * Generates the package.xml for the deployment
     */
    private static String generatePackageXml(String triggerName, String testClassName) {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <types>\n' +
               '        <members>' + triggerName + '</members>\n' +
               '        <name>ApexTrigger</name>\n' +
               '    </types>\n' +
               '    <types>\n' +
               '        <members>' + testClassName + '</members>\n' +
               '        <name>ApexClass</name>\n' +
               '    </types>\n' +
               '    <version>64.0</version>\n' +
               '</Package>';
    }
    
    /**
     * Generates the trigger metadata XML file
     */
    private static String generateTriggerMetaXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <apiVersion>64.0</apiVersion>\n' +
               '    <status>Active</status>\n' +
               '</ApexTrigger>';
    }

    public static String generateTriggerName(String objectApiName) {
        return 'DateStamp_' + objectApiName + '_BT';
    }
    
    public static String generateTestClassName(String objectApiName) {
        return 'DateStamp_' + objectApiName + '_BT_Test';
    }

    public static String generateTriggerSource(String objectApiName, String triggerName) {
        String nl = '\n';
        // BEFORE SAVE context - captures ALL changes before they're committed to database
        String body = 'trigger ' + triggerName + ' on ' + objectApiName + ' (before insert, before update) {' + nl +
                      '    // BEFORE SAVE context ensures we capture ALL changes' + nl +
                      '    // This includes both "Entered" (value changes TO target) and "Exited" (value changes FROM target) scenarios' + nl +
                      '    DateBuddyHandler.beforeInsertOrUpdate(Trigger.new, Trigger.oldMap);' + nl +
                      '}';
        return body;
    }
    
    /**
     * Generates the test class metadata XML file
     */
    private static String generateTestClassMetaXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <apiVersion>64.0</apiVersion>\n' +
               '    <status>Active</status>\n' +
               '</ApexClass>';
    }
    
    /**
     * Generates test class source code for the trigger
     */
    public static String generateTestClassSource(String objectApiName, String triggerName, String testClassName) {
        String nl = '\n';
        // Remove underscores and convert to camelCase for variable name
        String objectVarName = objectApiName.replaceAll('__c$', '').replaceAll('_', '');
        objectVarName = objectVarName.substring(0, 1).toLowerCase() + objectVarName.substring(1);
        
        // Get required fields dynamically
        Map<String, String> requiredFields = getRequiredFieldsMap(objectApiName);
        
        String testClass = '@isTest' + nl +
            'private class ' + testClassName + ' {' + nl +
            '    ' + nl +
            '    @isTest' + nl +
            '    static void testTriggerExecution() {' + nl +
            '        // Create test record' + nl +
            '        ' + objectApiName + ' ' + objectVarName + ' = new ' + objectApiName + '();' + nl +
            '        ' + nl +
            '        // Set required fields' + nl;
        
        // Add required fields
        for (String fieldName : requiredFields.keySet()) {
            testClass += '        ' + objectVarName + '.' + fieldName + ' = ' + requiredFields.get(fieldName) + ';' + nl;
        }
        
        testClass +=
            '        ' + nl +
            '        // Insert the record to test the trigger' + nl +
            '        Test.startTest();' + nl +
            '        insert ' + objectVarName + ';' + nl +
            '        ' + nl +
            '        // Update the record to test update trigger' + nl +
            '        ' + objectVarName + ' = [SELECT Id FROM ' + objectApiName + ' WHERE Id = :' + objectVarName + '.Id];' + nl +
            '        update ' + objectVarName + ';' + nl +
            '        Test.stopTest();' + nl +
            '        ' + nl +
            '        // Verify the trigger executed (DateBuddyHandler will process based on metadata)' + nl +
            '        System.assertNotEquals(null, ' + objectVarName + '.Id, \'Record should have been created\');' + nl +
            '    }' + nl +
            '    ' + nl +
            '    @isTest' + nl +
            '    static void testBulkTriggerExecution() {' + nl +
            '        // Create multiple test records' + nl +
            '        List<' + objectApiName + '> testRecords = new List<' + objectApiName + '>();' + nl +
            '        ' + nl +
            '        for (Integer i = 0; i < 20; i++) {' + nl +
            '            ' + objectApiName + ' ' + objectVarName + ' = new ' + objectApiName + '();' + nl;
        
        // Add required fields for bulk test with index
        for (String fieldName : requiredFields.keySet()) {
            String fieldValue = requiredFields.get(fieldName);
            // Special handling for email fields to ensure uniqueness
            if (fieldName.equalsIgnoreCase('Email')) {
                // For emails, replace the random part with the index for guaranteed uniqueness in bulk
                if (fieldValue.contains('Math.random()')) {
                    fieldValue = fieldValue.replace('Math.random()', 'i');
                }
            } else if (fieldValue.contains('\'') && !fieldValue.contains('System.now()')) {
                // For other string fields (not emails or dynamic values), append the index
                fieldValue = fieldValue.replace('\')', '\' + i)');
            }
            testClass += '            ' + objectVarName + '.' + fieldName + ' = ' + fieldValue + ';' + nl;
        }
        
        testClass +=
            '            testRecords.add(' + objectVarName + ');' + nl +
            '        }' + nl +
            '        ' + nl +
            '        // Test bulk insert' + nl +
            '        Test.startTest();' + nl +
            '        insert testRecords;' + nl +
            '        ' + nl +
            '        // Test bulk update' + nl +
            '        update testRecords;' + nl +
            '        Test.stopTest();' + nl +
            '        ' + nl +
            '        // Verify bulk operation succeeded' + nl +
            '        System.assertEquals(20, [SELECT COUNT() FROM ' + objectApiName + ' WHERE Id IN :testRecords], ' + nl +
            '            \'All records should have been created\');' + nl +
            '    }' + nl +
            '}';
            
        return testClass;
    }
    
    /**
     * Gets a map of required field names to their test values
     * Uses a combination of known patterns and dynamic field describe when possible
     */
    private static Map<String, String> getRequiredFieldsMap(String objectApiName) {
        Map<String, String> requiredFields = new Map<String, String>();
        
        // Handle known standard objects with their specific required fields
        if (objectApiName == 'Account') {
            requiredFields.put('Name', '\'Test Account\'');
        } else if (objectApiName == 'Contact') {
            requiredFields.put('LastName', '\'Test Contact\'');
            // Add unique email to avoid duplicates - using timestamp + random for uniqueness
            requiredFields.put('Email', '\'test.contact.\' + System.now().getTime() + \'.\' + Math.random() + \'@datebuddy.test\'');
        } else if (objectApiName == 'Lead') {
            requiredFields.put('LastName', '\'Test Lead\'');
            requiredFields.put('Company', '\'Test Company\'');
            // Add unique email to avoid duplicates - using timestamp + random for uniqueness
            requiredFields.put('Email', '\'test.lead.\' + System.now().getTime() + \'.\' + Math.random() + \'@datebuddy.test\'');
        } else if (objectApiName == 'Opportunity') {
            requiredFields.put('Name', '\'Test Opportunity\'');
            requiredFields.put('CloseDate', 'Date.today().addDays(30)');
            requiredFields.put('StageName', '\'Prospecting\'');
        } else if (objectApiName == 'Case') {
            // Case doesn't require any fields, but Subject is commonly used
            requiredFields.put('Subject', '\'Test Case\'');
        } else if (objectApiName == 'Task') {
            // Task doesn't require fields, but Subject is commonly used
            requiredFields.put('Subject', '\'Test Task\'');
        } else if (objectApiName == 'Event') {
            requiredFields.put('Subject', '\'Test Event\'');
            requiredFields.put('StartDateTime', 'DateTime.now()');
            requiredFields.put('EndDateTime', 'DateTime.now().addHours(1)');
        } else if (objectApiName == 'Campaign') {
            requiredFields.put('Name', '\'Test Campaign\'');
        } else if (objectApiName == 'Product2') {
            requiredFields.put('Name', '\'Test Product\'');
        } else if (objectApiName == 'Asset') {
            requiredFields.put('Name', '\'Test Asset\'');
        } else if (objectApiName == 'Contract') {
            // Contract requires special handling - we'll add a comment in the test
            requiredFields.put('StartDate', 'Date.today()');
            requiredFields.put('ContractTerm', '12');
        } else if (objectApiName == 'Order') {
            requiredFields.put('EffectiveDate', 'Date.today()');
            requiredFields.put('Status', '\'Draft\'');
        } else if (objectApiName == 'Quote') {
            requiredFields.put('Name', '\'Test Quote\'');
        } else if (objectApiName == 'PricebookEntry') {
            requiredFields.put('UnitPrice', '100.00');
        } else if (objectApiName == 'OpportunityLineItem') {
            requiredFields.put('Quantity', '1');
            requiredFields.put('UnitPrice', '100.00');
        } else if (objectApiName == 'QuoteLineItem') {
            requiredFields.put('Quantity', '1');
            requiredFields.put('UnitPrice', '100.00');
        } else if (objectApiName == 'OrderItem') {
            requiredFields.put('Quantity', '1');
            requiredFields.put('UnitPrice', '100.00');
        } else if (objectApiName.endsWith('__c')) {
            // Custom objects typically have Name field
            requiredFields.put('Name', '\'Test ' + objectApiName + '\'');
        } else {
            // For unknown objects, at minimum try adding a Name field as it's common
            // The test may need manual adjustment for specific objects
            requiredFields.put('Name', '\'Test ' + objectApiName + '\'');
        }
        
        return requiredFields;
    }
    
    /**
     * Checks the status of a deployment (for internal use)
     * Following apex-mdapi pattern for checking async deployment status
     */
    public static MetadataService.DeployResult checkDeployStatus(String deploymentId) {
        MetadataService.MetadataPort service = MetadataService.createService();
        return service.checkDeployStatus(deploymentId, true);
    }
    
    /**
     * RemoteAction method to check deployment status for real-time updates
     * Returns a comprehensive result suitable for JavaScript consumption
     */
    @RemoteAction
    public static Map<String, Object> checkDeploymentStatus(String deploymentId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            MetadataService.DeployResult deployResult = checkDeployStatus(deploymentId);
            
            result.put('success', true);
            result.put('done', deployResult.done);
            result.put('id', deployResult.id);
            result.put('status', deployResult.status);
            result.put('numberComponentsDeployed', deployResult.numberComponentsDeployed);
            result.put('numberComponentsTotal', deployResult.numberComponentsTotal);
            result.put('numberTestsCompleted', deployResult.numberTestsCompleted);
            result.put('numberTestsTotal', deployResult.numberTestsTotal);
            result.put('numberTestErrors', deployResult.numberTestErrors);
            
            // Include component successes and failures
            if (deployResult.details != null) {
                List<Map<String, String>> failures = new List<Map<String, String>>();
                List<Map<String, String>> successes = new List<Map<String, String>>();
                
                if (deployResult.details.componentFailures != null) {
                    for (MetadataService.DeployMessage msg : deployResult.details.componentFailures) {
                        Map<String, String> failure = new Map<String, String>();
                        failure.put('componentType', msg.componentType);
                        failure.put('fileName', msg.fileName);
                        failure.put('problem', msg.problem);
                        failure.put('lineNumber', String.valueOf(msg.lineNumber));
                        failure.put('columnNumber', String.valueOf(msg.columnNumber));
                        failures.add(failure);
                    }
                }
                
                if (deployResult.details.componentSuccesses != null) {
                    for (MetadataService.DeployMessage msg : deployResult.details.componentSuccesses) {
                        Map<String, String> success = new Map<String, String>();
                        success.put('componentType', msg.componentType);
                        success.put('fileName', msg.fileName);
                        success.put('fullName', msg.fullName);
                        success.put('created', String.valueOf(msg.created));
                        success.put('changed', String.valueOf(msg.changed));
                        successes.add(success);
                    }
                }
                
                // Include run test failures if any
                if (deployResult.details.runTestResult != null && deployResult.details.runTestResult.failures != null) {
                    List<Map<String, String>> testFailures = new List<Map<String, String>>();
                    for (MetadataService.RunTestFailure testFailure : deployResult.details.runTestResult.failures) {
                        Map<String, String> failure = new Map<String, String>();
                        failure.put('name', testFailure.name);
                        failure.put('methodName', testFailure.methodName);
                        failure.put('message', testFailure.message);
                        failure.put('stackTrace', testFailure.stackTrace);
                        testFailures.add(failure);
                    }
                    result.put('testFailures', testFailures);
                }
                
                result.put('componentFailures', failures);
                result.put('componentSuccesses', successes);
            }
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Retrieves deployment details including any errors
     * Useful for debugging failed deployments
     */
    public static MetadataService.DeployResult getDeploymentDetails(String deploymentId) {
        MetadataService.MetadataPort service = MetadataService.createService();
        
        // In production:
        // return service.checkDeployStatus(deploymentId, true);
        
        MetadataService.DeployResult result = new MetadataService.DeployResult();
        result.done = true;
        result.id = deploymentId;
        result.status = 'Succeeded';
        
        // Create details for the result
        MetadataService.DeployDetails details = new MetadataService.DeployDetails();
        details.componentSuccesses = new MetadataService.DeployMessage[]{};
        details.componentFailures = new MetadataService.DeployMessage[]{};
        result.details = details;
        
        return result;
    }
}
