# DateBuddy

Automated date field stamping for Salesforce - Track when picklist values change with automatic date stamping.

## Overview

DateBuddy is a Salesforce package that automatically tracks when specific picklist values change on any object by stamping date fields. It uses Custom Metadata Types for configuration, making it highly flexible and admin-friendly.

## Features

- **Automatic Date Stamping**: Tracks entry and exit dates when picklist values change
- **Flexible Configuration**: Uses Custom Metadata Types (no code changes needed)
- **Bidirectional Tracking**: Supports both "entered" and "exited" date tracking
- **Direction Support**: Handles "Entered/Exited" and "In/Out" direction values
- **Dynamic Trigger Deployment**: Deploy triggers via Lightning Web Component interface
- **Flow-Compatible**: Includes invocable action for Flow Builder integration

## Package Information

### 2GP Package Details
- **Package Name**: DateBuddy
- **Package ID**: 0HoWs0000001qqzKAA
- **Current Version**: 1.1.0-1
- **Subscriber Package Version ID**: 04tWs000000aW1NIAU
- **Package Type**: Unlocked
- **API Version**: 64.0

### Installation

#### Via URL
Install directly using this link:
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tWs000000aW1NIAU

#### Via Salesforce CLI
```bash
sf package install --package 04tWs000000aW1NIAU --target-org YOUR_ORG_ALIAS --wait 10
```

### Version History
- **1.1.0-1** (04tWs000000aW1NIAU) - Added MetadataServiceTest class
- **1.0.0-1** (04tWs000000aVzlIAE) - Initial release

## Components

### Custom Metadata Type
- **Date_Stamp_Mapping__mdt**: Configuration for field mappings
  - `Object_API_Name__c`: Target object
  - `Picklist_API_Name__c`: Picklist field to monitor
  - `Picklist_Value__c`: Value to track
  - `Date_Field_API_Name__c`: Entry date field
  - `Exit_Date_Field_API_Name__c`: Exit date field
  - `Direction__c`: Direction indicator (Entered/Exited/In/Out)

### Apex Classes
- **DateBuddyHandler**: Core trigger handler for date stamping
- **UpdateDateFieldAction**: Invocable action for Flow Builder
- **DateBuddyDeployController**: LWC controller for trigger deployment
- **DateStampTriggerDeployer**: Utility for deploying triggers dynamically

### Lightning Web Components
- **dateBuddyTriggerDeployer**: UI for deploying triggers to objects

## Configuration

1. Create Custom Metadata records in `Date_Stamp_Mapping__mdt`
2. Specify the object, picklist field, value, and date fields
3. Deploy triggers using the DateBuddy Trigger Deployer LWC
4. Date fields will automatically update when picklist values change

## Usage Example

To track when a Contact's Status changes to "Connected":

1. Create a Custom Metadata record:
   - Object API Name: `Contact`
   - Picklist API Name: `Contact_Status__c`
   - Picklist Value: `Connected`
   - Date Field API Name: `Date_Entered_Connected__c`
   - Exit Date Field API Name: `Date_Exited_Connected__c`

2. Deploy the trigger via the LWC interface

3. When Contact_Status__c changes to "Connected", Date_Entered_Connected__c is stamped
4. When Contact_Status__c changes from "Connected", Date_Exited_Connected__c is stamped

## Development

### Prerequisites
- Salesforce CLI
- DevHub org with 2GP enabled
- VS Code with Salesforce extensions (recommended)

### Building from Source
```bash
# Clone the repository
git clone [repository-url]

# Install dependencies
npm install

# Deploy to scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias datebuddy-scratch
sf project deploy start --target-org datebuddy-scratch

# Run tests
sf apex test run --target-org datebuddy-scratch --code-coverage
```

### Creating New Package Version
```bash
sf package version create --package DateBuddy --installation-key-bypass --wait 20
```

## License

See LICENSE file for details.

## Support

For issues or feature requests, please create an issue in the GitHub repository.