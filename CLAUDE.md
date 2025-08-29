# DateBuddy Project Documentation

## Project Overview
DateBuddy is a Salesforce application that automatically stamps date fields when picklist values change, tracking both when values are "Entered" and "Exited".

## Key Implementation Details

### Trigger Context - CRITICAL
- ALL DateBuddy triggers MUST run in BEFORE SAVE context (before insert, before update)
- This ensures we capture ALL changes before they're committed to the database
- Handles both "Entered" (value changes TO target) and "Exited" (value changes FROM target) scenarios

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
- `Date_Field_API_Name__c` - Date field to stamp
- `Direction__c` - "Entered" or "Exited" (optional)

### Handler Logic
DateBuddyHandler processes changes:
1. **Entered**: Stamps date when value changes TO the target value
2. **Exited**: Stamps date when value changes FROM the target value
3. **Legacy**: Backward compatibility for records without Direction specified

## Testing Requirements
- Minimum code coverage: 90%
- Always deploy ONLY the files being worked on
- Run tests after deployment to ensure functionality

## Development Notes
- Uses SFDX for deployment
- Deploy components individually when debugging
- All tests must pass before considering work complete

## TODO - Deployer LWC Enhancement
In the Deployer LWC page:
- Display objects as cards with CMDT-driven stats (e.g., "# Unique Fields Tracked")
- On object card click, open a modal containing:
  - Lightning-tree showing each unique tracked field on the object
  - Columns displaying:
    - Picklist Value
    - Enter field API name
    - Exit field API name
    - Other relevant metadata