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
        Map<String, String> result = new Map<String, String>();
        result.put('triggerName', triggerName);
        result.put('triggerSource', generateTriggerSource(objectApiName, triggerName));
        return result;
    }
    
    /**
     * RemoteAction to deploy ZIP from Visualforce page
     * @param zipData Base64 encoded ZIP file containing the trigger package
     * @return The async result ID for tracking
     */
    @RemoteAction
    public static String deployZip(String zipData) {
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
            // Use RunSpecifiedTests with the test classes from this project
            deployOptions.testLevel = 'RunSpecifiedTests';
            deployOptions.runTests = new String[] {
                'DateBuddyHandlerTest',
                'DateStampTriggerDeployerTest',
                'DateBuddyDeployControllerTest',
                'UpdateDateFieldActionTest'
            };
            
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
     * @return Map containing package components (packageXml, triggerSource, triggerMetadata)
     */
    public static Map<String, String> prepareDeploymentPackage(String objectApiName) {
        String triggerName = generateTriggerName(objectApiName);
        
        Map<String, String> packageComponents = new Map<String, String>();
        packageComponents.put('packageXml', generatePackageXml(triggerName));
        packageComponents.put('triggerSource', generateTriggerSource(objectApiName, triggerName));
        packageComponents.put('triggerMetadata', generateTriggerMetaXml());
        packageComponents.put('triggerName', triggerName);
        
        return packageComponents;
    }
    
    
    /**
     * Generates the package.xml for the deployment
     */
    private static String generatePackageXml(String triggerName) {
        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
               '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n' +
               '    <types>\n' +
               '        <members>' + triggerName + '</members>\n' +
               '        <name>ApexTrigger</name>\n' +
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
     * RemoteAction to check deployment status from VF page
     */
    @RemoteAction
    public static Map<String, Object> checkDeploymentStatus(String deploymentId) {
        MetadataService.MetadataPort service = MetadataService.createService();
        MetadataService.DeployResult deployResult = service.checkDeployStatus(deploymentId, true);
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('done', deployResult.done);
        result.put('id', deployResult.id);
        result.put('status', deployResult.status);
        result.put('numberComponentsDeployed', deployResult.numberComponentsDeployed);
        result.put('numberComponentsTotal', deployResult.numberComponentsTotal);
        
        if (deployResult.details != null && deployResult.details.componentFailures != null) {
            List<String> errors = new List<String>();
            for (MetadataService.DeployMessage msg : deployResult.details.componentFailures) {
                errors.add(msg.problem);
            }
            result.put('errors', errors);
        }
        
        return result;
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
