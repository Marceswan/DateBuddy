# DateBuddy Project Documentation

## Project Overview
DateBuddy is a Salesforce application that automatically stamps date fields when picklist values change, tracking both when values are "Entering" and "Exiting".

## Key Implementation Details

### Trigger Context - CRITICAL
- ALL DateBuddy triggers MUST run in BEFORE SAVE context (before insert, before update)
- This ensures we capture ALL changes before they're committed to the database
- Handles both "Entering" (value changes TO target) and "Exiting" (value changes FROM target) scenarios

### Metadata Deployment Approach
**IMPORTANT:** We use the JSZip method from apex-mdapi repository, NOT Zippex library.

Following the methodology from https://github.com/certinia/apex-mdapi:
- Uses Visualforce components (`<c:zip>`, `<c:zipEntry>`, `<c:unzip>`) to create ZIP packages
- JSZip library handles ZIP creation in the browser
- Deployment is done via MetadataService.deploy() with base64-encoded ZIP data

Key components:
1. **DateStampTriggerDeployer.deployZip()** - Receives base64 ZIP from Visualforce and deploys
2. **DateStampTriggerDeployer.prepareDeploymentPackage()** - Returns package components for VF page
3. Visualforce page uses JSZip components to create and deploy the package

### Custom Metadata Structure
Date_Stamp_Mapping__mdt fields:
- `Object_API_Name__c` - Target object
- `Picklist_API_Name__c` - Picklist field to monitor
- `Picklist_Value__c` - Value to track
- `Date_Field_API_Name__c` - Entry date field to stamp (Label: "Entry Date Field API Name")
- `Exit_Date_Field_API_Name__c` - Exit date field to stamp (optional)
- `Direction__c` - "Entering"/"Exiting"/"Entered"/"Exited"/"In"/"Out" (optional, used when only one date field is populated)
  - **Backward Compatibility**: System supports both old ("Entered"/"Exited") and new ("Entering"/"Exiting") Direction values

### Handler Logic
DateBuddyHandler processes changes based on populated fields:
1. **Both Entry & Exit fields present**: Entry field maps to "entering", Exit field maps to "exiting"
2. **Only Entry field present**:
   - If Direction is "Exiting"/"Exited"/"Out": Maps to exiting tracking
   - Otherwise: Maps to entering tracking (default)
3. **Only Exit field present**: ALWAYS maps to exiting tracking (Direction field is ignored)
4. **Direction Support**: Accepts "Entering"/"Exiting", "Entered"/"Exited", and "In"/"Out" as equivalent values

### Client-Side Processing Optimization
- **LWC Processing**: Direction determination and mapping classification is now handled client-side in the Lightning Web Component for improved performance
- **Reduced Apex Processing**: The LWC processes mapping classification to reduce server-side Apex processing time
- **Display Logic Fix**: DateBuddyDeployController display logic has been enhanced to properly handle mapping visualization

## Testing Requirements
- Minimum code coverage: 90%
- Always deploy ONLY the files being worked on
- Run tests after deployment to ensure functionality

### Test Coverage Achievements
- **DateBuddyHandler**: 96% coverage (up from 68%)
- **DateBuddyDeployController**: 82% coverage (up from 59%)
- **DateStampTriggerDeployer**: 86% coverage (up from 51%)
- **UpdateDateFieldAction**: 90% coverage (up from 45%)

### Test Stub Approach for CMDT Mocking
- Added `@TestVisible private static testMappings` field to DateBuddyHandler
- Tests can inject mock CMDT using JSON deserialization
- This allows testing of edge cases without actual CMDT records
- Enables comprehensive testing of complex scenarios and handler logic

## Development Notes
- Uses SFDX for deployment
- Deploy components individually when debugging
- All tests must pass before considering work complete

## 2GP Package Information
### Package Details
- **Package Name**: DateBuddy
- **Package ID**: 0HoWs0000001qqzKAA
- **Package Type**: Unlocked
- **DevHub**: GSO-Org (marc-zbcx@force.com)
- **API Version**: 64.0

### Current Version
- **Version Number**: 1.1.0-1
- **Subscriber Package Version ID**: 04tWs000000aW1NIAU
- **Installation URL**: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tWs000000aW1NIAU

### Version History
- **1.1.0-1** (04tWs000000aW1NIAU) - Added MetadataServiceTest class for improved test coverage
- **1.0.0-1** (04tWs000000aVzlIAE) - Initial release with core DateBuddy functionality

### Package Management Commands
```bash
# Create new package version
sf package version create --package DateBuddy --installation-key-bypass --wait 20 --skip-validation

# Install package
sf package install --package 04tWs000000aW1NIAU --target-org YOUR_ORG --wait 10

# List package versions
sf package version list --package DateBuddy
```

