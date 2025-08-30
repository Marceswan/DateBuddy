# DateBuddy Deployer LWC Enhancement - Implementation Plan

## Overview
Enhance the DateBuddy Trigger Deployer LWC to provide a more intuitive and informative interface using cards, modals, and detailed field tracking information.

## Current State Analysis
The current dateBuddyTriggerDeployer component:
- Displays objects in a combobox format
- Shows basic deploy functionality
- Lacks detailed CMDT information visualization
- No drill-down capability for field-level details

## Proposed Enhancement Architecture

### 1. Component Structure
```
dateBuddyTriggerDeployer (main component)
├── Object Cards View (Grid Layout)
│   ├── Individual Object Card
│   │   ├── Object Name
│   │   ├── Stats Badge (# of unique fields tracked)
│   │   ├── Total Mappings Count
│   │   └── Click Handler → Opens Modal
│   └── Deploy All Button
└── Field Details Modal
    ├── Modal Header (Object Name)
    ├── Lightning Tree (Field Structure)
    │   ├── Field Name (Parent Node)
    │   └── Picklist Values (Child Nodes)
    └── Data Table (Mapping Details)
        ├── Picklist Value
        ├── Entry Date Field API Name
        ├── Exit Date Field API Name
        └── Direction
```

### 2. Data Model Requirements

#### Apex Controller Updates (`DateBuddyDeployController`)

**New Methods Required:**
1. `getObjectsWithStats()` - Returns objects with CMDT statistics
   ```apex
   public static List<ObjectCardWrapper> getObjectsWithStats() {
       // Returns:
       // - objectApiName
       // - objectLabel
       // - uniqueFieldsCount
       // - totalMappingsCount
       // - hasDeployedTrigger
   }
   ```

2. `getObjectFieldMappings(String objectApiName)` - Returns detailed field mappings
   ```apex
   public static FieldMappingWrapper getObjectFieldMappings(String objectApiName) {
       // Returns:
       // - Tree structure data for lightning-tree
       // - Flat list for data table
       // - Field groupings by picklist field
   }
   ```

**Wrapper Classes:**
```apex
public class ObjectCardWrapper {
    @AuraEnabled public String objectApiName;
    @AuraEnabled public String objectLabel;
    @AuraEnabled public Integer uniqueFieldsCount;
    @AuraEnabled public Integer totalMappingsCount;
    @AuraEnabled public Boolean hasDeployedTrigger;
}

public class FieldMappingWrapper {
    @AuraEnabled public List<TreeNode> treeData;
    @AuraEnabled public List<MappingDetail> mappingDetails;
}

public class TreeNode {
    @AuraEnabled public String label;
    @AuraEnabled public String name;
    @AuraEnabled public Boolean expanded;
    @AuraEnabled public List<TreeNode> items;
}

public class MappingDetail {
    @AuraEnabled public String id;
    @AuraEnabled public String picklistField;
    @AuraEnabled public String picklistValue;
    @AuraEnabled public String entryDateField;
    @AuraEnabled public String exitDateField;
    @AuraEnabled public String direction;
}
```

### 3. LWC Component Updates

#### dateBuddyTriggerDeployer.html
```html
<template>
    <!-- Header -->
    <lightning-card title="DateBuddy Trigger Deployer">
        <lightning-button 
            slot="actions"
            label="Deploy All Triggers"
            onclick={handleDeployAll}>
        </lightning-button>
        
        <!-- Object Cards Grid -->
        <div class="slds-grid slds-wrap slds-grid_pull-padded">
            <template for:each={objectCards} for:item="card">
                <div key={card.objectApiName} 
                     class="slds-col slds-size_1-of-3 slds-p-around_small">
                    <lightning-card>
                        <!-- Card Content -->
                        <div onclick={handleCardClick} 
                             data-object={card.objectApiName}
                             class="card-clickable">
                            <h2 class="slds-text-heading_medium">
                                {card.objectLabel}
                            </h2>
                            <div class="stats-container">
                                <lightning-badge 
                                    label={card.uniqueFieldsLabel}>
                                </lightning-badge>
                                <lightning-badge 
                                    label={card.totalMappingsLabel}>
                                </lightning-badge>
                            </div>
                            <lightning-icon 
                                if:true={card.hasDeployedTrigger}
                                icon-name="utility:success">
                            </lightning-icon>
                        </div>
                        <!-- Individual Deploy Button -->
                        <lightning-button
                            slot="footer"
                            label="Deploy Trigger"
                            data-object={card.objectApiName}
                            onclick={handleDeployTrigger}>
                        </lightning-button>
                    </lightning-card>
                </div>
            </template>
        </div>
    </lightning-card>
    
    <!-- Field Details Modal -->
    <template if:true={showModal}>
        <section class="slds-modal slds-fade-in-open">
            <div class="slds-modal__container">
                <!-- Modal Header -->
                <header class="slds-modal__header">
                    <h2 class="slds-modal__title">
                        {selectedObjectLabel} - Field Mappings
                    </h2>
                    <lightning-button-icon
                        icon-name="utility:close"
                        onclick={closeModal}>
                    </lightning-button-icon>
                </header>
                
                <!-- Modal Body -->
                <div class="slds-modal__content">
                    <!-- Lightning Tree View -->
                    <div class="tree-container slds-m-bottom_medium">
                        <lightning-tree 
                            items={treeData}
                            header="Field Structure">
                        </lightning-tree>
                    </div>
                    
                    <!-- Data Table -->
                    <lightning-datatable
                        key-field="id"
                        data={mappingDetails}
                        columns={columns}
                        hide-checkbox-column>
                    </lightning-datatable>
                </div>
                
                <!-- Modal Footer -->
                <footer class="slds-modal__footer">
                    <lightning-button 
                        label="Close"
                        onclick={closeModal}>
                    </lightning-button>
                </footer>
            </div>
        </section>
        <div class="slds-backdrop slds-backdrop_open"></div>
    </template>
</template>
```

#### dateBuddyTriggerDeployer.js
```javascript
import { LightningElement, track, wire } from 'lwc';
import getObjectsWithStats from '@salesforce/apex/DateBuddyDeployController.getObjectsWithStats';
import getObjectFieldMappings from '@salesforce/apex/DateBuddyDeployController.getObjectFieldMappings';
import deployTrigger from '@salesforce/apex/DateBuddyDeployController.deployTrigger';

export default class DateBuddyTriggerDeployer extends LightningElement {
    @track objectCards = [];
    @track showModal = false;
    @track selectedObjectApiName;
    @track selectedObjectLabel;
    @track treeData = [];
    @track mappingDetails = [];
    
    columns = [
        { label: 'Picklist Field', fieldName: 'picklistField', type: 'text' },
        { label: 'Picklist Value', fieldName: 'picklistValue', type: 'text' },
        { label: 'Entry Date Field', fieldName: 'entryDateField', type: 'text' },
        { label: 'Exit Date Field', fieldName: 'exitDateField', type: 'text' },
        { label: 'Direction', fieldName: 'direction', type: 'text' }
    ];
    
    connectedCallback() {
        this.loadObjectCards();
    }
    
    loadObjectCards() {
        getObjectsWithStats()
            .then(result => {
                this.objectCards = result.map(card => ({
                    ...card,
                    uniqueFieldsLabel: `${card.uniqueFieldsCount} Unique Fields`,
                    totalMappingsLabel: `${card.totalMappingsCount} Total Mappings`
                }));
            })
            .catch(error => {
                // Error handling
            });
    }
    
    handleCardClick(event) {
        const objectApiName = event.currentTarget.dataset.object;
        this.selectedObjectApiName = objectApiName;
        this.selectedObjectLabel = this.objectCards.find(
            card => card.objectApiName === objectApiName
        ).objectLabel;
        
        // Load field mappings
        getObjectFieldMappings({ objectApiName })
            .then(result => {
                this.treeData = result.treeData;
                this.mappingDetails = result.mappingDetails;
                this.showModal = true;
            })
            .catch(error => {
                // Error handling
            });
    }
    
    handleDeployTrigger(event) {
        const objectApiName = event.target.dataset.object;
        // Implementation for single trigger deployment
    }
    
    handleDeployAll() {
        // Implementation for deploying all triggers
    }
    
    closeModal() {
        this.showModal = false;
        this.selectedObjectApiName = null;
        this.treeData = [];
        this.mappingDetails = [];
    }
}
```

#### dateBuddyTriggerDeployer.css
```css
.card-clickable {
    cursor: pointer;
    padding: 1rem;
    transition: background-color 0.2s;
}

.card-clickable:hover {
    background-color: #f3f2f2;
}

.stats-container {
    margin: 0.5rem 0;
    display: flex;
    gap: 0.5rem;
}

.tree-container {
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid #dddbda;
    padding: 0.5rem;
    border-radius: 0.25rem;
}

.slds-modal__container {
    max-width: 90%;
    width: 1200px;
}

.slds-modal__content {
    max-height: 70vh;
    overflow-y: auto;
}
```

## Implementation Steps

### Phase 1: Backend Development
1. ✅ Create wrapper classes in DateBuddyDeployController
2. ✅ Implement getObjectsWithStats() method
3. ✅ Implement getObjectFieldMappings() method
4. ✅ Write test methods for new functionality

### Phase 2: Frontend Card View
1. ✅ Update HTML to use card grid layout
2. ✅ Implement card component with stats badges
3. ✅ Add click handlers for cards
4. ✅ Style cards with hover effects

### Phase 3: Modal Implementation
1. ✅ Create modal structure in HTML
2. ✅ Implement lightning-tree data structure
3. ✅ Add lightning-datatable for details
4. ✅ Wire up data loading for modal

### Phase 4: Testing & Refinement
1. ✅ Test card interactions
2. ✅ Test modal data loading
3. ✅ Verify deploy functionality still works
4. ✅ Add error handling and loading states

### Phase 5: Deployment
1. ✅ Deploy to sandbox for testing
2. ✅ Run all test classes
3. ✅ Update package version
4. ✅ Document changes in README

## Success Criteria
- [ ] Objects display as interactive cards with CMDT statistics
- [ ] Clicking a card opens a modal with detailed field mappings
- [ ] Lightning-tree shows hierarchical field structure
- [ ] Data table displays all mapping details clearly
- [ ] Original deploy functionality remains intact
- [ ] Component is responsive and performs well with many objects
- [ ] Test coverage remains above 90%

## Project Dependencies & Integration Points

### Existing Files to Modify
1. **DateBuddyDeployController.cls**
   - Current methods: `listSObjects()`, `deployTrigger()`, `getDeploymentStatus()`
   - Add new methods while maintaining existing functionality
   - Reuse existing CMDT query logic where possible

2. **dateBuddyTriggerDeployer (LWC)**
   - Current files: `.html`, `.js`, `.js-meta.xml`
   - Preserve existing deploy functionality
   - Maintain backward compatibility

### Dependencies on Other Components
1. **Date_Stamp_Mapping__mdt**
   - Fields: Object_API_Name__c, Picklist_API_Name__c, Picklist_Value__c, Date_Field_API_Name__c, Exit_Date_Field_API_Name__c, Direction__c
   - Query patterns must align with DateBuddyHandler usage

2. **DateStampTriggerDeployer.cls**
   - Deploy methods remain unchanged
   - Ensure UI changes don't break deployment logic

3. **MetadataService.cls**
   - Used for trigger deployment
   - No changes needed, just ensure compatibility

## SLDS Design System Compliance

### Component Styling Guidelines
1. **Use SLDS Classes Exclusively**
   - Grid system: `slds-grid`, `slds-wrap`, `slds-col`
   - Spacing: `slds-p-*`, `slds-m-*` utilities
   - Typography: `slds-text-*` classes
   - Colors: SLDS color tokens only

2. **Card Component Structure**
   ```html
   <!-- SLDS Card Pattern -->
   <article class="slds-card">
       <div class="slds-card__header slds-grid">
           <header class="slds-media slds-media_center">
               <!-- Card header content -->
           </header>
       </div>
       <div class="slds-card__body">
           <!-- Card body with stats -->
       </div>
       <footer class="slds-card__footer">
           <!-- Action buttons -->
       </footer>
   </article>
   ```

3. **Modal Structure (SLDS Pattern)**
   ```html
   <section role="dialog" class="slds-modal slds-fade-in-open">
       <div class="slds-modal__container">
           <header class="slds-modal__header">
               <!-- Modal header -->
           </header>
           <div class="slds-modal__content">
               <!-- Modal content -->
           </div>
           <footer class="slds-modal__footer">
               <!-- Modal actions -->
           </footer>
       </div>
   </section>
   ```

4. **Color Tokens & Theming**
   - Success: `slds-theme_success`
   - Info badges: `slds-badge`
   - Hover states: Use SLDS interaction states
   - No custom colors - use SLDS design tokens

5. **Responsive Grid**
   - Desktop: `slds-size_1-of-3`
   - Tablet: `slds-medium-size_1-of-2`
   - Mobile: `slds-small-size_1-of-1`

### Updated CSS (SLDS Compliant)
```css
/* Only use for behaviors not covered by SLDS */
.datebuddy-card {
    transition: transform 0.2s ease-in-out;
}

.datebuddy-card:hover {
    transform: translateY(-2px);
    /* Use SLDS elevation tokens */
    box-shadow: var(--lwc-cardShadowHover);
}

.datebuddy-stats {
    /* Use SLDS spacing tokens */
    gap: var(--lwc-spacingSmall);
}

/* Ensure all custom classes are prefixed with 'datebuddy-' */
.datebuddy-modal-wide {
    /* Override only when necessary */
    max-width: 90vw !important;
}
```

## Technical Considerations
1. **Performance**: Lazy load modal data only when needed
2. **Scalability**: Handle orgs with many objects/mappings efficiently
3. **Error Handling**: Graceful degradation if CMDT queries fail
4. **Accessibility**: Ensure keyboard navigation and screen reader support
5. **Mobile**: Consider responsive design for mobile devices
6. **SLDS Compliance**: Strict adherence to Salesforce Lightning Design System
7. **Styling Consistency**: Use only SLDS classes and design tokens

## Efficiency & Performance Optimizations

### Query Optimization
1. **Single SOQL Query for Stats**
   ```apex
   // Efficient: Single query with aggregation
   SELECT Object_API_Name__c, 
          COUNT(DISTINCT Picklist_API_Name__c) uniqueFields,
          COUNT(Id) totalMappings
   FROM Date_Stamp_Mapping__mdt
   GROUP BY Object_API_Name__c
   ```

2. **Caching Strategy**
   - Cache object stats on initial load
   - Only query detailed mappings when modal opens
   - Use `@AuraEnabled(cacheable=true)` for read-only methods

3. **Lazy Loading Pattern**
   ```javascript
   // Load card data immediately
   connectedCallback() {
       this.loadObjectCards(); // Fast, aggregated data
   }
   
   // Load details only on demand
   handleCardClick(event) {
       if (!this.cachedMappings[objectApiName]) {
           // First time - fetch from server
           this.loadFieldMappings(objectApiName);
       } else {
           // Use cached data
           this.showCachedData(objectApiName);
       }
   }
   ```

### Component Efficiency
1. **Use `if:true` instead of `if:false` when possible**
   - Reduces DOM manipulation
   - Better performance for conditional rendering

2. **Implement Virtual Scrolling for Large Lists**
   ```javascript
   // For orgs with many objects
   const PAGE_SIZE = 12;
   @track visibleCards = [];
   @track allCards = [];
   
   loadMore() {
       const currentLength = this.visibleCards.length;
       const moreCards = this.allCards.slice(
           currentLength, 
           currentLength + PAGE_SIZE
       );
       this.visibleCards = [...this.visibleCards, ...moreCards];
   }
   ```

3. **Debounce Search/Filter Operations**
   ```javascript
   // Prevent excessive filtering
   handleSearchChange(event) {
       clearTimeout(this.searchTimeout);
       this.searchTimeout = setTimeout(() => {
           this.filterCards(event.target.value);
       }, 300);
   }
   ```

### Memory Management
1. **Clear Modal Data on Close**
   ```javascript
   closeModal() {
       // Release memory
       this.treeData = null;
       this.mappingDetails = null;
       this.selectedObjectApiName = null;
       this.showModal = false;
   }
   ```

2. **Use Efficient Data Structures**
   - Map for O(1) lookups instead of array.find()
   - Set for unique value tracking

### Error Prevention & Handling
1. **Defensive Programming**
   ```apex
   public static List<ObjectCardWrapper> getObjectsWithStats() {
       try {
           // Validate user permissions first
           if (!Schema.sObjectType.Date_Stamp_Mapping__mdt.isAccessible()) {
               throw new AuraHandledException('Insufficient permissions');
           }
           
           // Proceed with query
           List<AggregateResult> results = [
               SELECT Object_API_Name__c,
                      COUNT(DISTINCT Picklist_API_Name__c) uniqueFields,
                      COUNT(Id) totalMappings
               FROM Date_Stamp_Mapping__mdt
               GROUP BY Object_API_Name__c
               LIMIT 200  // Prevent governor limits
           ];
           
           return processResults(results);
       } catch (Exception e) {
           // Log error for debugging
           System.debug('Error in getObjectsWithStats: ' + e.getMessage());
           throw new AuraHandledException(e.getMessage());
       }
   }
   ```

2. **Graceful Degradation**
   ```javascript
   loadObjectCards() {
       getObjectsWithStats()
           .then(result => {
               this.processCardData(result);
           })
           .catch(error => {
               // Show user-friendly message
               this.showToast('Unable to load objects', 'error');
               // Fall back to basic list view
               this.showBasicView = true;
           });
   }
   ```

### Testing Strategy for Efficiency
1. **Test with Large Data Sets**
   - Create test data with multiple objects
   - Verify performance remains acceptable

2. **Monitor Governor Limits**
   - Track SOQL queries
   - Monitor heap size
   - Check CPU time

3. **Browser Performance**
   - Test with Chrome DevTools Performance tab
   - Ensure smooth 60fps animations
   - Check memory leaks with heap snapshots

## Risk Mitigation
- Keep original functionality as fallback
- Implement feature flag to toggle between old/new UI if needed
- Thoroughly test with various CMDT configurations
- Ensure backward compatibility with existing deployments
- Profile performance before and after changes
- Implement progressive enhancement (basic → enhanced UI)