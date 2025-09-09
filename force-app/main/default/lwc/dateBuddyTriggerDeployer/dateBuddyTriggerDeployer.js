import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deployTrigger from '@salesforce/apex/DateBuddyDeployController.deployTrigger';
import getStatus from '@salesforce/apex/DateBuddyDeployController.getStatus';
import getDetailedDeploymentStatus from '@salesforce/apex/DateBuddyDeployController.getDetailedDeploymentStatus';
import listSObjects from '@salesforce/apex/DateBuddyDeployController.listSObjects';
import getTriggerSource from '@salesforce/apex/DateBuddyDeployController.getTriggerSource';
import getObjectsWithStats from '@salesforce/apex/DateBuddyDeployController.getObjectsWithStats';
import getObjectFieldMappings from '@salesforce/apex/DateBuddyDeployController.getObjectFieldMappings';

export default class DateBuddyTriggerDeployer extends LightningElement {
    // Legacy properties (preserved for backward compatibility)
    @track objectApiName = '';
    @track isBusy = false;
    @track message = '';
    @track options = [];
    @track source = '';
    @track canRetry = false;
    pollTimer;

    // New card-based UI properties
    @track cards = [];
    @track isLoading = false;
    @track errorMessage = '';
    
    // Legacy mode properties
    @track showLegacyMode = false;
    @track legacyOptions = [];
    
    // Modal properties
    @track showModal = false;
    @track isLoadingModal = false;
    @track modalErrorMessage = '';
    @track selectedObjectApiName = '';
    @track selectedObjectLabel = '';
    @track treeData = [];
    @track tableData = [];
    @track tableColumns = [
        { label: 'Picklist Field', fieldName: 'picklistField', type: 'text' },
        { label: 'Picklist Value', fieldName: 'picklistValue', type: 'text' },
        { label: 'Date Field', fieldName: 'dateField', type: 'text' },
        { label: 'Direction', fieldName: 'direction', type: 'text' }
    ];
    
    // Deployment progress properties
    @track showDeploymentProgress = false;
    @track deploymentStatus = null;
    @track deploymentId = null;
    @track deploymentTestResults = [];
    @track deploymentErrors = [];
    @track isDeploying = false;
    @track deploymentCloseMessage = '';
    
    // Cache for performance
    _cardsCache = new Map();
    _fieldMappingsCache = new Map();

    async connectedCallback() {
        await this.loadCards();
        await this.loadLegacyOptions();
    }

    // New methods for enhanced UI
    async loadCards() {
        if (this._cardsCache.has('cards')) {
            this.cards = this._cardsCache.get('cards');
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        try {
            const cardData = await getObjectsWithStats();
            this.cards = cardData.map(card => ({
                ...card,
                objectApiName: card.objectName, // Map to expected property name
                objectLabel: card.objectName, // Use objectName as label for now
                hasDeployedTrigger: card.isDeployed || false, // Map isDeployed to hasDeployedTrigger
                cardAriaLabel: `${card.objectName} - ${card.fieldCount} unique fields, ${card.totalMappings} total mappings`,
                viewDetailsAriaLabel: `View field mapping details for ${card.objectName}`,
                deployAriaLabel: card.isDeployed ? `Re-deploy trigger for ${card.objectName}` : `Deploy trigger for ${card.objectName}`
            }));
            this._cardsCache.set('cards', this.cards);
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Failed to load objects with statistics';
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadLegacyOptions() {
        try {
            const names = await listSObjects();
            this.legacyOptions = names.map(n => ({ label: n, value: n }));
            this.options = [...this.legacyOptions]; // Keep backward compatibility
        } catch (error) {
            const errorMsg = error?.body?.message || error?.message || 'Failed to load objects';
            this.message = errorMsg;
        }
    }

    // Card interaction handlers
    handleCardClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const objectApiName = event.currentTarget.dataset.object;
        this.openModal(objectApiName);
    }

    handleCardKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            const objectApiName = event.currentTarget.dataset.object;
            this.openModal(objectApiName);
        }
    }

    handleViewDetailsClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const objectApiName = event.currentTarget.dataset.object;
        this.openModal(objectApiName);
    }

    handleDeployClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const objectApiName = event.currentTarget.dataset.object;
        this.objectApiName = objectApiName;
        this.deploy();
    }

    // Modal management
    async openModal(objectApiName) {
        const card = this.cards.find(c => c.objectApiName === objectApiName);
        if (!card) return;

        this.selectedObjectApiName = objectApiName;
        this.selectedObjectLabel = card.objectLabel;
        this.showModal = true;
        this.modalErrorMessage = '';
        
        await this.loadFieldMappings(objectApiName);
    }

    closeModal() {
        this.showModal = false;
        this.isLoadingModal = false;
        this.modalErrorMessage = '';
        this.selectedObjectApiName = '';
        this.selectedObjectLabel = '';
        
        // Clear modal data for memory management
        this.treeData = [];
        this.tableData = [];
    }

    async loadFieldMappings(objectApiName) {
        const cacheKey = `fieldMappings_${objectApiName}`;
        if (this._fieldMappingsCache.has(cacheKey)) {
            const cachedData = this._fieldMappingsCache.get(cacheKey);
            // Cached data is already processed
            this.treeData = cachedData.treeData;
            this.tableData = cachedData.tableData;
            return;
        }

        this.isLoadingModal = true;
        this.modalErrorMessage = '';
        try {
            const fieldMappings = await getObjectFieldMappings({ objectApiName });
            this.treeData = fieldMappings.treeNodes || [];
            
            // Process mapping details to determine actual direction based on field configuration
            this.tableData = (fieldMappings.mappingDetails || []).map(mapping => {
                // Determine actual direction based on DateBuddyHandler logic:
                // 1. If only Exit field present: ALWAYS "Exiting"
                // 2. If only Entry field present + Direction is 'Exited'/'Exiting'/'Out': "Exiting"
                // 3. Otherwise: "Entering"
                
                const hasEntryField = mapping.dateField && mapping.dateField.trim() !== '';
                const hasExitField = mapping.exitDateField && mapping.exitDateField.trim() !== '';
                
                let actualDirection;
                let displayDateField;
                
                if (hasExitField && !hasEntryField) {
                    // Only Exit field present - ALWAYS show as Exiting
                    actualDirection = 'Exiting';
                    displayDateField = mapping.exitDateField;
                } else if (hasEntryField && !hasExitField) {
                    // Only Entry field present - check Direction
                    // Support both old 'Exited' and new 'Exiting' values for compatibility
                    if (mapping.direction === 'Exited' || mapping.direction === 'Exiting' || mapping.direction === 'Out') {
                        actualDirection = 'Exiting';
                    } else {
                        actualDirection = 'Entering';
                    }
                    displayDateField = mapping.dateField;
                } else if (hasEntryField && hasExitField) {
                    // Both fields present - this shouldn't happen in single mapping
                    // but handle gracefully - convert old values to new
                    if (mapping.direction === 'Exited' || mapping.direction === 'Exiting' || mapping.direction === 'Out') {
                        actualDirection = 'Exiting';
                    } else {
                        actualDirection = 'Entering';
                    }
                    displayDateField = mapping.dateField;
                } else {
                    // Neither field present - shouldn't happen but handle gracefully
                    actualDirection = mapping.direction || 'Unknown';
                    displayDateField = '';
                }
                
                return {
                    ...mapping,
                    direction: actualDirection,
                    dateField: displayDateField
                };
            });
            
            // Cache the processed data
            this._fieldMappingsCache.set(cacheKey, {
                treeData: this.treeData,
                tableData: this.tableData
            });
        } catch (error) {
            this.modalErrorMessage = error?.body?.message || error?.message || 'Failed to load field mappings';
            this.showToast('Error', this.modalErrorMessage, 'error');
        } finally {
            this.isLoadingModal = false;
        }
    }

    handleModalDeploy() {
        this.objectApiName = this.selectedObjectApiName;
        this.closeModal();
        this.deploy();
    }

    // Tree selection handler
    handleTreeSelection(event) {
        const selectedName = event.detail.name;
        console.log('Selected tree node:', selectedName);
        // Additional logic for tree selection can be added here
    }

    // Legacy mode toggle
    toggleLegacyMode() {
        this.showLegacyMode = !this.showLegacyMode;
    }
    
    closeDeploymentProgress() {
        this.showDeploymentProgress = false;
        this.deploymentStatus = null;
        this.deploymentTestResults = [];
        this.deploymentErrors = [];
        this.deploymentCloseMessage = '';
    }
    
    get hasTestResults() {
        return this.deploymentTestResults && this.deploymentTestResults.length > 0;
    }
    
    get hasDeploymentErrors() {
        return this.deploymentErrors && this.deploymentErrors.length > 0;
    }
    
    get deploymentProgressPercent() {
        if (!this.deploymentStatus || !this.deploymentStatus.numberComponentsTotal) return 0;
        return Math.round((this.deploymentStatus.numberComponentsDeployed / this.deploymentStatus.numberComponentsTotal) * 100);
    }
    
    get testProgressPercent() {
        if (!this.deploymentStatus || !this.deploymentStatus.numberTestsTotal) return 0;
        return Math.round((this.deploymentStatus.numberTestsCompleted / this.deploymentStatus.numberTestsTotal) * 100);
    }
    
    get failedTests() {
        return this.deploymentTestResults.filter(test => test.outcome === 'Fail');
    }
    
    get passedTests() {
        return this.deploymentTestResults.filter(test => test.outcome === 'Pass');
    }
    
    get deploymentProgressStyle() {
        return `width: ${this.deploymentProgressPercent}%`;
    }
    
    get testProgressStyle() {
        const hasErrors = this.deploymentStatus && this.deploymentStatus.numberTestErrors > 0;
        const color = hasErrors ? 'background-color: #c23934;' : '';
        return `width: ${this.testProgressPercent}%; ${color}`;
    }
    
    checkForValidationRuleConflict(detailedStatus) {
        // Check test results for validation rule conflicts
        if (detailedStatus.testResults) {
            for (const test of detailedStatus.testResults) {
                if (test.message && test.message.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                    return true;
                }
            }
        }
        
        // Check component errors for validation rule conflicts
        if (detailedStatus.componentErrors) {
            for (const error of detailedStatus.componentErrors) {
                if (error && error.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                    return true;
                }
            }
        }
        
        return false;
    }

    handleLegacyChange(event) {
        this.handleChange(event);
    }

    // Computed properties
    get hasModalData() {
        return (this.treeData && this.treeData.length > 0) || (this.tableData && this.tableData.length > 0);
    }

    // Utility methods
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    // Legacy methods (preserved for backward compatibility)
    handleChange(event) {
        this.objectApiName = event.detail.value;
        this.source = '';
        this.canRetry = false;
    }

    get isDeployDisabled() {
        return this.isBusy || !this.objectApiName;
    }

    get isRetryDisabled() {
        return this.isBusy || !this.objectApiName || !this.canRetry;
    }

    get isViewSourceDisabled() {
        return this.isBusy || !this.objectApiName;
    }

    async deploy() {
        this.isBusy = true;
        this.message = '';
        try {
            // Open VF page in a new window for JSZip-based deployment
            const vfUrl = `/apex/DateBuddyDeploy?objectApiName=${encodeURIComponent(this.objectApiName)}`;
            const deployWindow = window.open(vfUrl, 'deployWindow', 'width=600,height=400');
            
            // Poll the VF page for deployment result
            this.message = 'Deployment window opened. Processing...';
            
            // Check for deployment result from VF page
            const checkInterval = setInterval(() => {
                try {
                    if (deployWindow.closed) {
                        clearInterval(checkInterval);
                        this.message = 'Deployment window closed';
                        this.canRetry = true;
                        this.isBusy = false;
                    } else if (deployWindow.deploymentResult) {
                        clearInterval(checkInterval);
                        const result = deployWindow.deploymentResult;
                        if (result.success) {
                            this.message = `Deployment started. AsyncResult Id: ${result.asyncResultId}`;
                            this.startPolling(result.asyncResultId);
                        } else {
                            this.message = result.error || 'Deployment failed';
                            this.canRetry = true;
                        }
                        deployWindow.close();
                        this.isBusy = false;
                    }
                } catch (e) {
                    // Cross-origin error is expected, continue polling
                }
            }, 1000);
            
            // Timeout after 30 seconds
            setTimeout(() => {
                clearInterval(checkInterval);
                if (!deployWindow.closed) {
                    deployWindow.close();
                }
                if (this.isBusy) {
                    this.message = 'Deployment timed out';
                    this.canRetry = true;
                    this.isBusy = false;
                }
            }, 30000);
            
        } catch (e) {
            this.message = e?.body?.message || e?.message || 'Deployment failed';
            this.canRetry = true;
            this.isBusy = false;
        }
    }

    startPolling(asyncId) {
        this.deploymentId = asyncId;
        this.showDeploymentProgress = true;
        this.isDeploying = true;
        
        let attempts = 0;
        const maxAttempts = 60; // ~60s for longer deployments
        const intervalMs = 1000;
        this.clearPoll();
        
        this.pollTimer = setInterval(async () => {
            attempts++;
            try {
                // Get detailed deployment status
                const detailedStatus = await getDetailedDeploymentStatus({ deploymentId: asyncId });
                
                // Update deployment status display
                this.deploymentStatus = detailedStatus;
                this.deploymentTestResults = detailedStatus.testResults || [];
                this.deploymentErrors = detailedStatus.componentErrors || [];
                
                // Update message with progress
                if (detailedStatus.numberComponentsTotal > 0) {
                    this.message = `Deploying: ${detailedStatus.numberComponentsDeployed}/${detailedStatus.numberComponentsTotal} components`;
                }
                if (detailedStatus.numberTestsTotal > 0) {
                    this.message += ` | Tests: ${detailedStatus.numberTestsCompleted}/${detailedStatus.numberTestsTotal}`;
                }
                
                if (detailedStatus.done || attempts >= maxAttempts) {
                    if (detailedStatus.done) {
                        const isSuccess = detailedStatus.status === 'Succeeded';
                        const hasTestFailures = detailedStatus.numberTestErrors > 0;
                        
                        // Check for validation rule conflicts
                        const hasValidationRuleConflict = this.checkForValidationRuleConflict(detailedStatus);
                        
                        if (hasValidationRuleConflict) {
                            // Show sticky toast for validation rule conflicts
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Validation Rule Conflict',
                                    message: 'Validation Rule Conflict detected. Please disable the rule and try again',
                                    variant: 'error',
                                    mode: 'sticky'  // User must dismiss
                                })
                            );
                        }
                        
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: isSuccess ? 'Trigger Deployed' : 'Deployment Failed',
                                message: isSuccess 
                                    ? `Successfully deployed ${detailedStatus.numberComponentsDeployed} components` 
                                    : (hasTestFailures 
                                        ? `${detailedStatus.numberTestErrors} test(s) failed. See details below.` 
                                        : 'Deployment failed. Check details below.'),
                                variant: isSuccess ? 'success' : 'error',
                                mode: isSuccess ? 'dismissible' : 'sticky'  // Sticky for errors
                            })
                        );
                        this.canRetry = !isSuccess;
                        this.isDeploying = false;
                        
                        if (isSuccess) {
                            try {
                                this.source = await getTriggerSource({ objectApiName: this.objectApiName });
                                // Refresh cards to show updated deployment status
                                await this.loadCards();
                                
                                // Show success toast with deployment details
                                this.dispatchEvent(
                                    new ShowToastEvent({
                                        title: '✅ Deployment Successful!',
                                        message: `Trigger for ${this.objectApiName} has been deployed successfully. This window will close automatically.`,
                                        variant: 'success',
                                        mode: 'dismissible'
                                    })
                                );
                                
                                // Update message to inform about auto-close
                                this.deploymentCloseMessage = 'Success! Closing automatically...';
                                
                                // Auto-close deployment window after showing success message
                                setTimeout(() => {
                                    this.closeDeploymentProgress();
                                }, 2000);
                            } catch (e) {
                                console.error('Failed to load trigger source:', e);
                            }
                        } else {
                            // On failure, add a message to inform user they can close when ready
                            this.deploymentCloseMessage = 'You can close this window when you\'re ready after reviewing the errors.';
                        }
                    } else if (attempts >= maxAttempts) {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Deployment Timed Out',
                                message: 'Stopped polling after 60s. Check status later.',
                                variant: 'warning'
                            })
                        );
                        this.canRetry = true;
                        this.isDeploying = false;
                    }
                    this.clearPoll();
                }
            } catch (e) {
                // Fall back to simple status if detailed status fails
                try {
                    const status = await getStatus({ asyncId });
                    this.message = `Status: ${status.state}${status.message ? ' — ' + status.message : ''}`;
                    if (status.done || attempts >= maxAttempts) {
                        this.handleSimpleStatusComplete(status, attempts, maxAttempts);
                        this.clearPoll();
                    }
                } catch (fallbackError) {
                    this.message = fallbackError?.body?.message || fallbackError?.message || 'Status check failed';
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Status Check Error',
                            message: this.message,
                            variant: 'error'
                        })
                    );
                    this.canRetry = true;
                    this.isDeploying = false;
                    this.clearPoll();
                }
            }
        }, intervalMs);
    }
    
    handleSimpleStatusComplete(status, attempts, maxAttempts) {
        if (status.done) {
            const isSuccess = status.state === 'Completed';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: isSuccess ? 'Trigger Deployed' : 'Deployment Failed',
                    message: isSuccess ? 'Metadata API reported Completed.' : (status.message || 'See debug logs for details.'),
                    variant: isSuccess ? 'success' : 'error'
                })
            );
            this.canRetry = !isSuccess;
            this.isDeploying = false;
        } else if (attempts >= maxAttempts) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Deployment Timed Out',
                    message: 'Stopped polling after 60s. Check status later.',
                    variant: 'warning'
                })
            );
            this.canRetry = true;
            this.isDeploying = false;
        }
    }

    clearPoll() {
        if (this.pollTimer) {
            clearInterval(this.pollTimer);
            this.pollTimer = undefined;
        }
    }

    async retry() {
        if (!this.objectApiName || this.isBusy) return;
        this.message = '';
        this.source = '';
        this.canRetry = false;
        await this.deploy();
    }

    async viewSource() {
        if (!this.objectApiName) return;
        if (this.source) return; // already loaded
        try {
            this.source = await getTriggerSource({ objectApiName: this.objectApiName });
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Source Load Failed',
                message: e?.body?.message || e?.message || 'Could not load trigger source',
                variant: 'warning'
            }));
        }
    }
}
