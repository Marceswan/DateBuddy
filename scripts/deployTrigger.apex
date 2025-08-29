// Example: Deploy a before-save trigger for a specific object using apex-mdapi
// Prereqs: Remote Site Setting to your org base URL and MetadataService.cls present.

String objectApiName = 'Opportunity'; // change as needed
MetadataService.AsyncResult[] results = DateStampTriggerDeployer.deploy(objectApiName);
System.debug('Started deployment for ' + objectApiName + ' -> ' + results);

