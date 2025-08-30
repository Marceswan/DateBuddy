# DateBuddy

[![Salesforce API](https://img.shields.io/badge/Salesforce%20API-v64.0-blue)](https://developer.salesforce.com/)
[![Package Version](https://img.shields.io/badge/Package%20Version-1.1.0--1-green)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tWs000000aW1NIAU)
[![Code Coverage](https://img.shields.io/badge/Code%20Coverage-90%2B%25-brightgreen)](https://trailhead.salesforce.com/content/learn/modules/apex_testing)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Automated date field stamping for Salesforce - Track when picklist values are entered and exited with precision

## 📋 Overview

DateBuddy is a powerful Salesforce application that automatically stamps date fields when picklist values change. It provides comprehensive tracking of both when values are "Entered" (changed TO a target value) and "Exited" (changed FROM a target value), enabling precise audit trails and business process monitoring.

The application uses Custom Metadata Types for configuration, making it highly flexible and admin-friendly without requiring code changes.

## ✨ Features

- **🎯 Automatic Date Stamping**: Automatically populate date fields when picklist values change
- **🔄 Bidirectional Tracking**: Track both "Entered" and "Exited" states for complete audit trails
- **⚙️ Metadata-Driven Configuration**: Easy setup through Custom Metadata Types (no code changes required)
- **🚀 Dynamic Trigger Deployment**: Automatically generate and deploy triggers for configured objects
- **📊 Lightning Web Component UI**: User-friendly interface for configuration and deployment
- **🔧 Flexible Direction Mapping**: Support for "Entered"/"Exited" and "In"/"Out" direction values
- **🔗 Flow-Compatible**: Includes invocable action for Flow Builder integration
- **📦 2GP Package**: Easy installation via Second Generation Package

## 🚀 Installation

### Via Salesforce Package (Recommended)

1. **Install the DateBuddy package** using the latest version:
   ```
   https://login.salesforce.com/packaging/installPackage.apexp?p0=04tWs000000aW1NIAU
   ```

2. **Grant appropriate permissions** to users who will configure DateBuddy:
   - Custom Metadata Types access
   - Modify All Data (for trigger deployment)

3. **Navigate to the DateBuddy app** in the App Launcher

### Via Salesforce CLI

```bash
# Install the package
sf package install --package 04tWs000000aW1NIAU --target-org YOUR_ORG_ALIAS --wait 10

# Verify installation
sf package installed list --target-org YOUR_ORG_ALIAS
```

### Via SFDX Project (Development)

```bash
# Clone the repository
git clone [repository-url]
cd DateBuddy

# Deploy to your org
sf project deploy start --target-org [your-org-alias]

# Run tests
sf apex run test --target-org [your-org-alias] --code-coverage
```

## ⚙️ Configuration Guide

### Setting Up Date Stamp Mappings

DateBuddy uses Custom Metadata Type records (`Date_Stamp_Mapping__mdt`) for configuration:

1. **Navigate to Setup → Custom Metadata Types → Date Stamp Mapping → Manage Records**

2. **Create a new record** with the following fields:

| Field | Description | Required |
|-------|-------------|----------|
| `Object_API_Name__c` | Target object API name (e.g., `Account`, `Custom_Object__c`) | ✅ |
| `Picklist_API_Name__c` | Picklist field to monitor (e.g., `Status__c`) | ✅ |
| `Picklist_Value__c` | Specific picklist value to track (e.g., `Active`) | ✅ |
| `Date_Field_API_Name__c` | Entry date field API name | ✅* |
| `Exit_Date_Field_API_Name__c` | Exit date field API name | ❌ |
| `Direction__c` | Direction when only one date field is used (`Entered`/`Exited`/`In`/`Out`) | ❌ |

**\* Required unless `Exit_Date_Field_API_Name__c` is populated**

## 🎯 Field Configuration Logic

Understanding how DateBuddy maps your configuration to date stamping behavior is crucial for proper setup. The system uses a sophisticated logic to determine when to stamp entry vs. exit dates based on which fields you populate.

### Configuration Rules

| Field Configuration | Behavior | Direction Field Effect |
|-------------------|----------|----------------------|
| **Both `Date_Field_API_Name__c` AND `Exit_Date_Field_API_Name__c` populated** | Entry field tracks ENTRY events<br/>Exit field tracks EXIT events | **IGNORED** - Two fields = bidirectional tracking |
| **ONLY `Date_Field_API_Name__c` populated** | Default: Tracks ENTRY events<br/>Exception: If Direction = "Exited" or "Out" → Tracks EXIT events | **RESPECTED** - Determines tracking direction |
| **ONLY `Exit_Date_Field_API_Name__c` populated** | Always tracks EXIT events | **IGNORED** - Exit field always means exit tracking |

### Detailed Configuration Logic

#### Scenario 1: Bidirectional Tracking (Both Fields Populated)
When both date fields are specified, DateBuddy automatically provides complete entry/exit tracking:

```
Date_Field_API_Name__c: Entry_Date__c           → Stamps when value ENTERS
Exit_Date_Field_API_Name__c: Exit_Date__c       → Stamps when value EXITS
Direction__c: [ANY VALUE]                       → IGNORED
```

**Result**: Full lifecycle tracking with separate timestamps for entry and exit events.

#### Scenario 2: Single Field - Entry Tracking (Default)
When only the entry field is populated, DateBuddy defaults to entry tracking:

```
Date_Field_API_Name__c: Status_Date__c          → Stamps when value ENTERS
Exit_Date_Field_API_Name__c: [BLANK]            → Not used
Direction__c: [BLANK/NULL/Entered/In]           → Entry tracking (default)
```

**Result**: Only entry events are tracked.

#### Scenario 3: Single Field - Exit Tracking (Override)
Use the Direction field to override default behavior for exit tracking:

```
Date_Field_API_Name__c: Status_Date__c          → Stamps when value EXITS
Exit_Date_Field_API_Name__c: [BLANK]            → Not used  
Direction__c: Exited OR Out                     → Forces exit tracking
```

**Result**: Only exit events are tracked using the entry field.

#### Scenario 4: Exit Field Only
When only the exit field is populated, it always tracks exits:

```
Date_Field_API_Name__c: [BLANK]                 → Not used
Exit_Date_Field_API_Name__c: Exit_Date__c       → Stamps when value EXITS
Direction__c: [ANY VALUE]                       → IGNORED
```

**Result**: Only exit events are tracked.

### Direction Field Values

| Direction Value | Synonym | Behavior |
|----------------|---------|----------|
| `Entered` | `In` | Forces entry tracking when only one field is populated |
| `Exited` | `Out` | Forces exit tracking when only one field is populated |
| `null`/`blank` | - | Uses default behavior based on field configuration |

## 📚 Comprehensive Configuration Examples

### Example 1: Complete Lifecycle Tracking
**Use Case**: Track both when Opportunities enter and exit "Negotiation" stage

```
Label: Opportunity Negotiation Lifecycle
Object_API_Name__c: Opportunity
Picklist_API_Name__c: StageName  
Picklist_Value__c: Negotiation
Date_Field_API_Name__c: Negotiation_Entry_Date__c
Exit_Date_Field_API_Name__c: Negotiation_Exit_Date__c
Direction__c: [Leave blank - ignored for bidirectional]
```

**Behavior**:
- When StageName changes TO "Negotiation" → `Negotiation_Entry_Date__c` = TODAY
- When StageName changes FROM "Negotiation" → `Negotiation_Exit_Date__c` = TODAY

### Example 2: Entry-Only Tracking
**Use Case**: Track when Opportunities reach "Closed Won" (never need exit date)

```
Label: Opportunity Closed Won Entry
Object_API_Name__c: Opportunity
Picklist_API_Name__c: StageName
Picklist_Value__c: Closed Won
Date_Field_API_Name__c: Closed_Won_Date__c
Exit_Date_Field_API_Name__c: [Leave blank]
Direction__c: Entered (or leave blank - default behavior)
```

**Behavior**:
- When StageName changes TO "Closed Won" → `Closed_Won_Date__c` = TODAY
- When StageName changes FROM "Closed Won" → Nothing happens

### Example 3: Exit-Only Tracking with Direction Override
**Use Case**: Track when Accounts leave "Qualification" status (using single field for exit)

```
Label: Account Qualification Exit
Object_API_Name__c: Account  
Picklist_API_Name__c: Account_Status__c
Picklist_Value__c: Qualification
Date_Field_API_Name__c: Qualification_Left_Date__c
Exit_Date_Field_API_Name__c: [Leave blank]
Direction__c: Exited
```

**Behavior**:
- When Account_Status__c changes TO "Qualification" → Nothing happens
- When Account_Status__c changes FROM "Qualification" → `Qualification_Left_Date__c` = TODAY

### Example 4: Multiple Values - Same Object
**Use Case**: Track different stages of the same opportunity with separate date fields

```
Configuration Set 1:
Label: Opportunity Prospecting Entry
Object_API_Name__c: Opportunity
Picklist_API_Name__c: StageName
Picklist_Value__c: Prospecting  
Date_Field_API_Name__c: Prospecting_Date__c

Configuration Set 2:
Label: Opportunity Qualification Entry  
Object_API_Name__c: Opportunity
Picklist_API_Name__c: StageName
Picklist_Value__c: Qualification
Date_Field_API_Name__c: Qualification_Date__c

Configuration Set 3:
Label: Opportunity Closed Won Entry
Object_API_Name__c: Opportunity  
Picklist_API_Name__c: StageName
Picklist_Value__c: Closed Won
Date_Field_API_Name__c: Closed_Won_Date__c
```

**Behavior**: Each stage transition stamps its respective date field, building a complete timeline.

### Example 5: Complex Custom Object Scenario
**Use Case**: Service Request lifecycle with bidirectional tracking for "In Progress" and exit-only for resolution

```
Configuration Set 1:
Label: Service Request In Progress Lifecycle
Object_API_Name__c: Service_Request__c
Picklist_API_Name__c: Status__c
Picklist_Value__c: In Progress
Date_Field_API_Name__c: In_Progress_Start_Date__c
Exit_Date_Field_API_Name__c: In_Progress_End_Date__c

Configuration Set 2:  
Label: Service Request Resolution
Object_API_Name__c: Service_Request__c
Picklist_API_Name__c: Status__c
Picklist_Value__c: Resolved
Date_Field_API_Name__c: Resolution_Date__c
```

**Behavior**:
- Status → "In Progress": `In_Progress_Start_Date__c` = TODAY
- Status away from "In Progress": `In_Progress_End_Date__c` = TODAY  
- Status → "Resolved": `Resolution_Date__c` = TODAY

## 🔧 Usage Scenarios and Walkthroughs

### Scenario 1: Sales Pipeline Tracking

**Business Requirement**: Track progression through opportunity stages with detailed timestamps.

**Step-by-Step Setup**:

1. **Identify Fields Needed**:
   - Opportunity object has standard `StageName` field
   - Create custom date fields for each stage you want to track

2. **Create Custom Date Fields** (Setup → Object Manager → Opportunity):
   ```
   Prospecting_Date__c (Date field)
   Qualification_Date__c (Date field)  
   Needs_Analysis_Date__c (Date field)
   Proposal_Date__c (Date field)
   Closed_Won_Date__c (Date field)
   ```

3. **Configure DateBuddy Mappings** (Setup → Custom Metadata Types → Date Stamp Mapping):

   **Record 1 - Prospecting Entry**:
   ```
   Label: Opportunity Prospecting Stage Entry
   Object_API_Name__c: Opportunity
   Picklist_API_Name__c: StageName
   Picklist_Value__c: Prospecting
   Date_Field_API_Name__c: Prospecting_Date__c
   Exit_Date_Field_API_Name__c: [blank]
   Direction__c: [blank - defaults to entry]
   ```

   **Record 2 - Qualification Entry**:
   ```
   Label: Opportunity Qualification Stage Entry  
   Object_API_Name__c: Opportunity
   Picklist_API_Name__c: StageName
   Picklist_Value__c: Qualification
   Date_Field_API_Name__c: Qualification_Date__c
   ```

   **Record 3 - Needs Analysis Entry**:
   ```
   Label: Opportunity Needs Analysis Stage Entry
   Object_API_Name__c: Opportunity  
   Picklist_API_Name__c: StageName
   Picklist_Value__c: Needs Analysis
   Date_Field_API_Name__c: Needs_Analysis_Date__c
   ```

   **Record 4 - Proposal Entry**:
   ```
   Label: Opportunity Proposal Stage Entry
   Object_API_Name__c: Opportunity
   Picklist_API_Name__c: StageName  
   Picklist_Value__c: Proposal/Price Quote
   Date_Field_API_Name__c: Proposal_Date__c
   ```

   **Record 5 - Closed Won Entry**:
   ```
   Label: Opportunity Closed Won Entry
   Object_API_Name__c: Opportunity
   Picklist_API_Name__c: StageName
   Picklist_Value__c: Closed Won  
   Date_Field_API_Name__c: Closed_Won_Date__c
   ```

4. **Deploy Trigger**:
   - Open DateBuddy app
   - Go to Trigger Deployer tab
   - Select "Opportunity" from available objects
   - Click "Deploy Triggers"

5. **Test the Configuration**:
   - Create or edit an Opportunity
   - Change StageName from "Prospecting" to "Qualification"
   - Verify `Prospecting_Date__c` was stamped when it entered Prospecting
   - Verify `Qualification_Date__c` was stamped when it entered Qualification

### Scenario 2: Customer Status Lifecycle Management

**Business Requirement**: Track customer lifecycle with both entry and exit dates for "Active" status, plus resolution tracking.

**Step-by-Step Setup**:

1. **Custom Object Setup** (assuming Customer__c custom object):
   ```
   Customer_Status__c (Picklist: New, Onboarding, Active, Inactive, Churned)
   Active_Start_Date__c (Date field)
   Active_End_Date__c (Date field) 
   Churned_Date__c (Date field)
   ```

2. **DateBuddy Configuration**:

   **Record 1 - Active Lifecycle (Bidirectional)**:
   ```
   Label: Customer Active Status Lifecycle
   Object_API_Name__c: Customer__c
   Picklist_API_Name__c: Customer_Status__c
   Picklist_Value__c: Active
   Date_Field_API_Name__c: Active_Start_Date__c
   Exit_Date_Field_API_Name__c: Active_End_Date__c
   Direction__c: [blank - ignored for bidirectional]
   ```

   **Record 2 - Churn Tracking (Entry Only)**:
   ```
   Label: Customer Churn Entry
   Object_API_Name__c: Customer__c  
   Picklist_API_Name__c: Customer_Status__c
   Picklist_Value__c: Churned
   Date_Field_API_Name__c: Churned_Date__c
   ```

3. **Expected Behavior**:
   - Customer Status → "Active": `Active_Start_Date__c` = TODAY
   - Customer Status away from "Active": `Active_End_Date__c` = TODAY
   - Customer Status → "Churned": `Churned_Date__c` = TODAY

## ❗ Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Date Fields Not Being Stamped

**Symptoms**:
- Configuration looks correct but date fields remain blank
- No errors visible to users

**Diagnostic Steps**:
1. **Check Field Permissions**:
   ```
   Setup → Object Manager → [Object] → Fields & Relationships → [Date Field] → Set Field-Level Security
   ```
   Ensure the field is **visible** and **editable** for relevant profiles.

2. **Verify Field API Names**:
   - Confirm the exact API name in Object Manager
   - API names are case-sensitive and must include `__c` for custom fields
   - Standard fields like `StageName` don't have `__c`

3. **Check Picklist Values**:
   - Verify the exact picklist value spelling and capitalization
   - Check for leading/trailing spaces in the configuration

4. **Confirm Trigger Deployment**:
   - Navigate to Setup → Apex Triggers
   - Look for trigger named `DateBuddyTrigger_[ObjectAPIName]`
   - If missing, redeploy through DateBuddy interface

**Common Fixes**:
```
❌ Wrong: Date_Field_API_Name__c: myDateField
✅ Correct: Date_Field_API_Name__c: myDateField__c

❌ Wrong: Picklist_Value__c: closed won  
✅ Correct: Picklist_Value__c: Closed Won

❌ Wrong: Object_API_Name__c: opportunities
✅ Correct: Object_API_Name__c: Opportunity
```

#### Issue 2: Wrong Dates Being Stamped (Entry vs Exit Confusion)

**Symptoms**:
- Dates are stamped but at the wrong time (exit when expected entry, or vice versa)

**Diagnostic Steps**:
1. **Review Configuration Logic** (see Field Configuration Logic section above)
2. **Check Direction Field**:
   - If only one date field is populated, ensure Direction is set correctly
   - Remember: Direction is ignored when both date fields are populated

**Resolution Examples**:

**Problem**: Want to track when Opportunity exits "Qualification" but date stamps when entering instead.

❌ **Incorrect Configuration**:
```
Date_Field_API_Name__c: Qualification_Date__c
Exit_Date_Field_API_Name__c: [blank]
Direction__c: [blank]  ← This defaults to ENTRY tracking
```

✅ **Correct Configuration**:
```  
Date_Field_API_Name__c: Qualification_Date__c
Exit_Date_Field_API_Name__c: [blank]
Direction__c: Exited  ← Forces EXIT tracking
```

#### Issue 3: Multiple Mappings Causing Conflicts

**Symptoms**:
- Unexpected date stamps
- Dates being overwritten
- Performance issues

**Diagnostic Steps**:
1. **Audit All Mappings** for the object:
   ```
   Setup → Custom Metadata Types → Date Stamp Mapping → Manage Records
   Filter by Object_API_Name__c
   ```

2. **Look for Overlapping Configurations**:
   - Same picklist value with different date fields
   - Different Direction settings for same value/field combination

**Resolution**:
- Ensure each picklist value + direction combination maps to only one date field
- If you need multiple date stamps for the same event, use separate metadata records with different date fields

**Example of Proper Multiple Mappings**:
```
✅ Valid: Multiple values, different fields
Record 1: StageName = "Prospecting" → Prospecting_Date__c  
Record 2: StageName = "Qualification" → Qualification_Date__c

✅ Valid: Same value, entry vs exit to different fields
Record 1: Status = "Active" → Active_Start_Date__c + Active_End_Date__c (bidirectional)

❌ Invalid: Same value, same direction, different fields  
Record 1: StageName = "Prospecting" → Date_Field_1__c (Direction: Entered)
Record 2: StageName = "Prospecting" → Date_Field_2__c (Direction: Entered)
```

#### Issue 4: Trigger Deployment Failures

**Symptoms**:
- "Deployment failed" messages in DateBuddy interface
- Metadata API errors

**Diagnostic Steps**:
1. **Check User Permissions**:
   - User needs "Modify All Data" or equivalent permissions
   - User needs access to deploy metadata

2. **Review Deployment Logs**:
   - Check debug logs for specific error messages
   - Look for field permission or API name errors

3. **Validate Object and Field Existence**:
   - Ensure target object exists and is accessible
   - Confirm all referenced date fields exist

**Common Deployment Errors and Fixes**:

**Error**: "INVALID_FIELD: No such column 'Field_Name__c'"
```
✅ Fix: Verify the field exists and API name is correct
```

**Error**: "INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY"  
```
✅ Fix: Grant field-level security access for the date fields
```

**Error**: "DUPLICATE_DEVELOPER_NAME"
```
✅ Fix: Previous trigger deployment may have failed partially
     Go to Setup → Apex Triggers → Delete existing trigger → Redeploy
```

### Debug Mode Testing

For advanced troubleshooting, enable debug logging:

1. **Setup → Debug Logs → New**
2. **Select your user**  
3. **Set Apex Code level to FINEST**
4. **Reproduce the issue**
5. **Review logs for DateBuddyHandler entries**

Look for log entries like:
```
DEBUG|DateBuddyHandler: Processing field change: Status__c from 'Old Value' to 'New Value'
DEBUG|DateBuddyHandler: Matched mapping for Opportunity.Status__c = 'Active'
DEBUG|DateBuddyHandler: Stamping entry date on field: Active_Date__c
```

### Trigger Deployment

After creating your metadata records:

1. **Open the DateBuddy Lightning App**
2. **Navigate to the Trigger Deployer** tab
3. **Select your target object** from the available configurations
4. **Click "Deploy Triggers"** to generate and deploy the necessary triggers

The system will automatically:
- Generate trigger code based on your metadata configuration
- Deploy triggers using the Salesforce Metadata API
- Validate the deployment and report status

## 📊 Test Coverage Status

DateBuddy maintains high code quality standards:

- **Minimum Required Coverage**: 90%
- **Current Coverage**: 90%+
- **Test Classes**:
  - `DateBuddyHandlerTest`
  - `DateStampTriggerDeployerTest`
  - `DateBuddyDeployControllerTest`
  - `UpdateDateFieldActionTest`
  - `MetadataServiceTest`

Run tests after any configuration changes:
```bash
sf apex run test --target-org [your-org] --code-coverage
```

## 🎯 Use Cases

### Sales Process Tracking
Track when opportunities move through different stages:
- **Qualification Date**: When `StageName` becomes `Qualified`
- **Proposal Date**: When `StageName` becomes `Proposal`
- **Closed Won Date**: When `StageName` becomes `Closed Won`

### Customer Lifecycle Management
Monitor customer status changes:
- **Onboarding Start**: When `Customer_Status__c` becomes `Onboarding`
- **Active Date**: When `Customer_Status__c` becomes `Active`
- **Churn Date**: When `Customer_Status__c` leaves `Active`

### Compliance and Audit
Maintain detailed audit trails:
- **Approval Dates**: Track when records are approved
- **Review Cycles**: Monitor when reviews are completed
- **Status Changes**: Log all critical status transitions

## 💡 Usage Example

To track when a Contact's Status changes to "Connected":

1. **Create a Custom Metadata record**:
   - Object API Name: `Contact`
   - Picklist API Name: `Contact_Status__c`
   - Picklist Value: `Connected`
   - Date Field API Name: `Date_Entered_Connected__c`
   - Exit Date Field API Name: `Date_Exited_Connected__c`

2. **Deploy the trigger** via the LWC interface

3. **Automatic date stamping**:
   - When `Contact_Status__c` changes TO "Connected" → `Date_Entered_Connected__c` is stamped
   - When `Contact_Status__c` changes FROM "Connected" → `Date_Exited_Connected__c` is stamped

## 🛠️ Development Setup

### Prerequisites

- Salesforce CLI (sf)
- VS Code with Salesforce Extension Pack
- Access to a Salesforce org with appropriate permissions
- DevHub org with 2GP enabled (for package development)

### Local Development

1. **Clone the repository**:
   ```bash
   git clone [repository-url]
   cd DateBuddy
   ```

2. **Authorize your DevHub**:
   ```bash
   sf org login web --set-default-dev-hub --alias MyDevHub
   ```

3. **Create a scratch org**:
   ```bash
   sf org create scratch --definition-file config/project-scratch-def.json --alias DateBuddyScratch --set-default
   ```

4. **Deploy source**:
   ```bash
   sf project deploy start
   ```

5. **Run tests**:
   ```bash
   sf apex run test --code-coverage
   ```

### Architecture Notes

- **Trigger Context**: All DateBuddy triggers run in BEFORE SAVE context
- **Deployment Method**: Uses JSZip methodology from apex-mdapi (not Zippex)
- **Handler Logic**: Centralized in `DateBuddyHandler` class
- **Metadata Service**: Custom implementation for dynamic trigger deployment

### Key Components

#### Custom Metadata Type
- **Date_Stamp_Mapping__mdt**: Configuration for field mappings
  - `Object_API_Name__c`: Target object
  - `Picklist_API_Name__c`: Picklist field to monitor
  - `Picklist_Value__c`: Value to track
  - `Date_Field_API_Name__c`: Entry date field
  - `Exit_Date_Field_API_Name__c`: Exit date field
  - `Direction__c`: Direction indicator (Entered/Exited/In/Out)

#### Apex Classes
- **DateBuddyHandler**: Core trigger handler for date stamping
- **UpdateDateFieldAction**: Invocable action for Flow Builder
- **DateBuddyDeployController**: LWC controller for trigger deployment
- **DateStampTriggerDeployer**: Utility for deploying triggers dynamically
- **MetadataService**: Metadata API wrapper for deployments

#### Lightning Web Components
- **dateBuddyTriggerDeployer**: UI for deploying triggers to objects

## 📦 Package Information

### Current Version
- **Package Name**: DateBuddy
- **Package ID**: `0HoWs0000001qqzKAA`
- **Current Version**: 1.1.0-1
- **Subscriber Package Version ID**: `04tWs000000aW1NIAU`
- **Package Type**: Unlocked
- **DevHub**: GSO-Org (marc-zbcx@force.com)
- **API Version**: 64.0

### Installation URL
```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tWs000000aW1NIAU
```

### Version History
- **1.1.0-1** (`04tWs000000aW1NIAU`) - Added MetadataServiceTest class for improved test coverage
- **1.0.0-1** (`04tWs000000aVzlIAE`) - Initial release with core DateBuddy functionality

### Package Management Commands

```bash
# Create new package version
sf package version create --package DateBuddy --installation-key-bypass --wait 20 --skip-validation

# Install package
sf package install --package 04tWs000000aW1NIAU --target-org YOUR_ORG --wait 10

# List package versions
sf package version list --package DateBuddy
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Standards

- Maintain 90%+ test coverage
- Follow Salesforce development best practices
- Update documentation for new features
- Test in scratch org before submitting PR
- Deploy ONLY the files being worked on directly

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For issues, questions, or contributions:

- **Issues**: [GitHub Issues](../../issues)
- **Documentation**: This README and inline code comments
- **Salesforce Trailblazer Community**: Search for "DateBuddy"

---

**Made with ❤️ for the Salesforce Community**