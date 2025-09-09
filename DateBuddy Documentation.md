# DateBuddy — Apex + LWC Documentation

## Overview
DateBuddy automates date stamping on Salesforce records when a configured picklist field changes. It supports both Entered (value changed TO X) and Exited (value changed FROM X) semantics, configured via Custom Metadata (CMDT) and executed by a single, bulk-safe before-save Apex handler. Triggers are generated and deployed per-object using a Lightning Web Component (LWC) with a Visualforce (VF) deployment bridge powered by the apex-mdapi MetadataService.

Core goals:
- Declarative configuration using CMDT (`Date_Stamp_Mapping__mdt`).
- One generic Apex handler (`DateBuddyHandler`) called from per-object before-save triggers.
- Self-serve trigger deployment via LWC, with status, test results, and retry.
- Flow compatibility through the `UpdateDateFieldAction` invocable, using the same CMDT.


## Key Components
- Apex
  - `force-app/main/default/classes/DateBuddyHandler.cls`: Bulk-safe before-save logic that stamps date fields based on CMDT mappings.
  - `force-app/main/default/classes/DateBuddyDeployController.cls`: LWC backend that lists configured objects/fields, provides generated trigger source view, starts deployments (via VF bridge), and polls detailed deployment status (tests, component errors).
  - `force-app/main/default/classes/DateStampTriggerDeployer.cls`: Deployment generator and VF RemoteActions. Builds trigger/test class sources and deploys ZIP via apex-mdapi.
  - `force-app/main/default/classes/UpdateDateFieldAction.cls`: Flow-compatible invocable that simulates the field change and calls `DateBuddyHandler` to stamp dates.
  - `force-app/main/default/classes/MetadataService.cls`: Vendored apex-mdapi library used for deployments and status checks.
- LWC
  - `force-app/main/default/lwc/dateBuddyTriggerDeployer/`: Card view of configured objects, detail modal with mappings, deploy button, status progress, test results, and retry.
- Visualforce
  - `force-app/main/default/pages/DateBuddyDeploy.page`: VF bridge that uses JSZip to assemble a metadata ZIP (trigger + test + package.xml) and calls `DateStampTriggerDeployer.deployZip`.
  - `force-app/main/default/pages/DateBuddySession.page`: Session bridge page that returns the running session Id (used by apex-mdapi patterns when needed).
- Static Resource
  - `force-app/main/default/staticresources/jsziplib.resource`: JSZip library used by the VF deployment page.
- Custom Metadata
  - `Date_Stamp_Mapping__mdt`: Declarative mappings of picklist value transitions to date fields.


## Custom Metadata (CMDT) — `Date_Stamp_Mapping__mdt`
Each record defines a rule that maps a specific picklist field/value to a date field to stamp when the value is “entered” and/or “exited”. Supported fields:
- `Object_API_Name__c` (Text): API name of the target object (e.g., `Account`).
- `Picklist_API_Name__c` (Text): API name of the picklist field to watch (e.g., `Account_Status__c`).
- `Picklist_Value__c` (Text): The exact picklist value to monitor (e.g., `Active`).
- `Date_Field_API_Name__c` (Text, optional): API name of the date field to stamp for Entered direction.
- `Exit_Date_Field_API_Name__c` (Text, optional): API name of the date field to stamp for Exited direction.
- `Direction__c` (Text, optional): Disambiguates when only one date field is provided. Accepted values: `Entered`/`In` or `Exited`/`Out`.

Direction rules implemented by `DateBuddyHandler`:
- If both `Date_Field_API_Name__c` and `Exit_Date_Field_API_Name__c` are populated: stamp both directions accordingly.
- If only `Date_Field_API_Name__c` is populated:
  - Direction = `Exited`/`Out` -> treat as Exited mapping.
  - Otherwise (including blank) -> treat as Entered mapping.
- If only `Exit_Date_Field_API_Name__c` is populated: always treat as Exited mapping.

Stamping behavior:
- Date values are set to `Date.today()` when the rule triggers.
- Dates are only stamped if the destination date field is currently null to preserve historical accuracy.
- Handler is bulk-safe and does not throw; it silently logs when `LOG_DEBUG` is enabled for tests.

Example CMDT configurations (illustrative):
- Object `Account`, picklist `Account_Status__c`
  - Entered: `Active`, `Available`, `Churn`, `Demo`, `Discovery`, `Inactive`, `Listed`, `Lost`, `New`, `Prospecting`, `Redlining`, `Refused`, `Research` -> stamps corresponding `Date_Entered_<Value>__c` fields.
  - Exited: same values as above -> stamps corresponding `Date_Exited_<Value>__c` fields.
  - Additional business stages:
    - `Business Case`, `Contract Negotiation`, `Partnership Definition` with `Direction__c` set to Entered or Exited and a `Date_(Entered|Exited)_<Stage>__c` field.
- Object `Contact`, picklist `Contact_Status__c`
  - Entered: `Connected` -> `Date_Entered_Connected__c`.
  - Exited: `Connected` -> `Date_Exited_Connected__c`.

You can add or edit CMDT records under `force-app/main/default/customMetadata/` or from Setup → Custom Metadata Types.


## Trigger Naming and Structure
- Naming: `DateStamp_<Object>_BT` (e.g., `DateStamp_Account_BT`).
- Context: `before insert, before update` only (before-save flow, fastest and avoids extra DML).
- Body: Single-line invocation of the generic handler:
  - `DateBuddyHandler.beforeInsertOrUpdate(Trigger.new, Trigger.oldMap);`

Triggers are generated by `DateStampTriggerDeployer` and deployed per-object through the VF deployment flow, bundled with a minimal coverage test class `DateStamp_<Object>_Test`.


## How It Works (Data Flow)
1) Configure Rules (Admin)
- Create `Date_Stamp_Mapping__mdt` records for each Object / Picklist / Value you want to capture, pointing to the appropriate date field(s) and optional Direction.

2) Generate and Deploy Trigger (Builder/Admin)
- LWC (`dateBuddyTriggerDeployer`) embedded in the `DateBuddy` tab shows cards for all objects that have CMDT records.
- Click “Deploy Trigger…” on an object card; the LWC opens `DateBuddyDeploy.page?objectApiName=<Object>`.
- The VF page calls `DateStampTriggerDeployer.prepareDeploymentPackage(objectApiName)` to get:
  - `package.xml`, trigger source, trigger meta, generated test class source/meta.
- VF uses JSZip (static resource) to assemble a base64 ZIP and calls `DateStampTriggerDeployer.deployZip(zip, objectApiName)`.
- `DateStampTriggerDeployer` invokes apex-mdapi (`MetadataService.deploy`) and returns an AsyncResult Id.
- The LWC polls `DateBuddyDeployController.getDetailedDeploymentStatus(deploymentId)` to show live progress, deploy/test counts, failures, and toast notifications. It falls back to `getStatus(asyncId)` if the detailed check fails.

3) Runtime (Users/Data)
- When users insert or update records, the generated trigger calls `DateBuddyHandler.beforeInsertOrUpdate`.
- The handler loads and caches the relevant CMDT mappings per object, compares `Trigger.oldMap` vs `Trigger.new`, computes Entered and Exited transitions per configured picklist value, and stamps the correct date fields if null.

4) Optional Flow Path
- Flows can call `UpdateDateFieldAction.updateDateField` with object, picklist field, value, direction (optional), and record Id. The action batches records per object, queries only necessary fields (from CMDT + picklist), simulates the picklist change in memory, invokes `DateBuddyHandler`, and updates records in bulk.


## LWC UX Details (`dateBuddyTriggerDeployer`)
- Object Cards: Derived from `DateBuddyDeployController.getObjectsWithStats()`:
  - Unique picklist field count, total mappings, number of entry/exit mappings, and whether a trigger exists (SOQL check by name).
- Details Modal: Uses `getObjectFieldMappings(objectApiName)` to show a tree and table of mappings. The table normalizes Direction using the same logic as `DateBuddyHandler` (e.g., “only Exit field populated” => Exiting).
- Deployment:
  - Opens the VF page to initiate deployment.
  - Polls `getDetailedDeploymentStatus` until done or timeout (~60s); shows component progress, test results, and component errors.
  - On success: shows toast, displays generated trigger source (via `getTriggerSource`), refreshes cards, and auto-closes the progress UI.
  - On failure or timeout: exposes “Retry Deploy” and shows sticky error toasts for common validation-rule conflicts.


## Dependencies and Prerequisites
- apex-mdapi: `MetadataService.cls` is vendored and must be deployed to the org.
- Visualforce session page: `DateBuddySession.page` is included and should be accessible (used by apex-mdapi patterns).
- VF deploy page: `DateBuddyDeploy.page` is used by the LWC to construct and submit the deployment ZIP.
- Static Resource: `jsziplib` must be present for VF ZIP assembly.
- Remote Site Settings: Add one Remote Site setting pointing to your org’s base URL (e.g., `https://your-domain.my.salesforce.com`). Do NOT use Named Credentials for this workflow.
- Permissions: Users initiating deployments need access to the VF page and Apex classes; production deployments require appropriate permissions to run Metadata API.


## Setup and Installation
1) Deploy the metadata to your org
- `sf deploy metadata -o <alias> --metadata ApexClass,ApexTrigger`

2) Configure Remote Site Setting
- Setup → Security → Remote Site Settings → New:
  - Remote Site URL: `https://your-domain.my.salesforce.com` (your org base URL)

3) Verify VF Pages
- Ensure both `/apex/DateBuddySession` and `/apex/DateBuddyDeploy` exist in the org and are accessible.

4) Add the LWC to a Lightning page
- App Builder → Add `dateBuddyTriggerDeployer` to an admin utility or setup app page.

5) Seed or adjust CMDT
- Add/modify `Date_Stamp_Mapping__mdt` records to match your objects, fields, and values.

6) Deploy first trigger
- From the LWC, click “Deploy Trigger” for your target object.
- Alternatively (power users): run Anonymous Apex to start the flow, then finish via VF UI as implemented:
  - `sf apex run -o <alias> --file scripts/deployTrigger.apex`


## Testing and Validation
- Run all DateBuddy unit tests:
  - `sf apex test run -o <alias> --tests DateBuddyHandlerTest,DateStampTriggerDeployerTest,DateBuddyDeployControllerTest --result-format human`
- Verify coverage of touched classes is ≥ 85%.
- After deployment, create/update sample records to confirm date fields stamp on Entered/Exited transitions as configured.


## Performance, Bulk Safety, and Limits
- The handler:
  - Runs only before-save (no extra DML), stamps only when destination date field is null.
  - Caches per-transaction mapping config and field describes per object (`CONFIG_CACHE`, `FIELD_MAP_CACHE`).
  - Avoids DML/SOQL in loops, processes bulk updates safely, and deduplicates work using a per-transaction signature set.
- The LWC polls status at 1–2s intervals with a fixed attempt count to avoid excessive callouts.


## Error Handling and Troubleshooting
- Validation rules: Deployment test failures referencing `FIELD_CUSTOM_VALIDATION_EXCEPTION` are detected and displayed with sticky toasts. Temporarily disable rules or adjust test generation accordingly.
- Missing apex-mdapi or VF pages: Ensure `MetadataService.cls`, `DateBuddyDeploy.page`, and `DateBuddySession.page` are deployed.
- Remote Site Setting: Must point to the org base URL only; Named Credentials are not used in this implementation.
- Trigger not found after deploy: The card shows deployed state via SOQL for `DateStamp_<Object>_BT`. If missing, re-run deploy and check component errors.
- CMDT misconfiguration: If a picklist/date field API name does not exist on the object, that mapping is skipped at runtime (no exception is thrown). Use the modal’s “Detailed View” to validate.


## Reference: Important Files
- Handler
  - `force-app/main/default/classes/DateBuddyHandler.cls`
- LWC
  - `force-app/main/default/lwc/dateBuddyTriggerDeployer/`
- Deployment (Apex)
  - `force-app/main/default/classes/DateStampTriggerDeployer.cls`
  - `force-app/main/default/classes/DateBuddyDeployController.cls`
  - `force-app/main/default/classes/MetadataService.cls`
- Visualforce + Static Resource
  - `force-app/main/default/pages/DateBuddyDeploy.page`
  - `force-app/main/default/pages/DateBuddySession.page`
  - `force-app/main/default/staticresources/jsziplib.resource`
- Scripts
  - `scripts/deployTrigger.apex`
- Custom Metadata
  - `force-app/main/default/customMetadata/Date_Stamp_Mapping.*.md`


## CLI Commands
- Deploy classes/triggers: `sf deploy metadata -o <alias> --metadata ApexClass,ApexTrigger`
- Run Apex tests: `sf apex test run -o <alias> --result-format human`
- Launch Anonymous Apex example: `sf apex run -o <alias> --file scripts/deployTrigger.apex`


## Notes and Conventions
- Indentation: 4 spaces; target line length ~120.
- Trigger naming: `DateStamp_<Object>_BT`.
- Apex methods: `camelCase`. Tests follow `<ClassName>Test` names and `testMethodName_pattern` conventions.
- Avoid SOQL/DML in loops; use bulk-safe patterns.
- Do not test the presence of CMDT data itself; mock where appropriate for unit tests.


## Appendix: End-to-End Example
1) Configure CMDT for `Account` → `Account_Status__c` = `Active`:
- `Date_Field_API_Name__c` = `Date_Entered_Active__c` (Entered)
- `Direction__c` = `Entered`

2) Deploy the trigger for `Account` from the LWC.

3) Create an Account:
- Set `Account_Status__c = Active` on insert, or update from some other value to `Active`.
- The handler stamps `Date_Entered_Active__c = Date.today()` if it was null.

4) Later, move away from `Active`:
- Update `Account_Status__c` from `Active` to another value.
- If an Exited mapping exists for `Active`, the handler stamps `Date_Exited_Active__c` if null (using either `Exit_Date_Field_API_Name__c` or `Direction__c = Exited`).