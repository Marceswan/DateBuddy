import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deployTrigger from '@salesforce/apex/DateBuddyDeployController.deployTrigger';
import getStatus from '@salesforce/apex/DateBuddyDeployController.getStatus';
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
    
    // Deployment status tracking
    @track deploymentStatus = null;
    @track showDeploymentStatus = false;
    @track deploymentErrors = [];
    @track deploymentTestFailures = [];
    
    // Cache for performance
    _cardsCache = new Map();
    _fieldMappingsCache = new Map();

    async connectedCallback() {
        await this.loadCards();
        await this.loadLegacyOptions();
        
        // Listen for deployment status messages from VF page
        window.addEventListener('message', this.handleDeploymentMessage.bind(this));
    }
    
    disconnectedCallback() {
        window.removeEventListener('message', this.handleDeploymentMessage.bind(this));
    }
    
    handleDeploymentMessage(event) {
        // Handle messages from the VF deployment page
        if (event.data && event.data.type) {
            if (event.data.type === 'deploymentStatus') {
                this.updateDeploymentStatus(event.data.status);
            } else if (event.data.type === 'deploymentComplete') {
                this.handleDeploymentComplete(event.data.status);
            }
        }
    }
    
    updateDeploymentStatus(status) {
        this.deploymentStatus = status;
        this.showDeploymentStatus = true;
        
        // Update the message with current status
        if (status.numberComponentsTotal) {
            this.message = `Deploying: ${status.numberComponentsDeployed || 0}/${status.numberComponentsTotal} components`;
        }
        if (status.numberTestsTotal) {
            this.message += ` | Tests: ${status.numberTestsCompleted || 0}/${status.numberTestsTotal}`;
            if (status.numberTestErrors) {
                this.message += ` (${status.numberTestErrors} errors)`;
            }
        }
    }
    
    handleDeploymentComplete(status) {
        this.deploymentStatus = status;
        this.showDeploymentStatus = true;
        this.isBusy = false;
        
        // Store reference to deployment window if it exists
        const deployWindow = this.deploymentWindow;
        
        if (status.status === 'Succeeded') {
            this.message = 'Deployment successful!';
            this.showToast('Success', 'Trigger deployed successfully', 'success');
            // Refresh cards to show updated deployment status
            this.loadCards();
            
            // Close the deployment window on success
            if (deployWindow && !deployWindow.closed) {
                setTimeout(() => {
                    deployWindow.close();
                }, 1500); // Give user a moment to see success message
            }
        } else {
            this.message = 'Deployment failed. See errors below.';
            this.processDeploymentErrors(status);
            
            // For failures, update the window with a message but don't close
            if (deployWindow && !deployWindow.closed) {
                try {
                    // Try to update the window content with a user message
                    const messageDiv = deployWindow.document.getElementById('deploymentProgress');
                    if (messageDiv) {
                        messageDiv.innerHTML += '<br/><br/><div style="padding: 10px; background: #f4f6f9; border-radius: 4px;">' +
                            '<strong>Deployment failed.</strong><br/>' +
                            'You can close this window when you\'re ready.<br/>' +
                            'Error details are displayed in the main window.</div>';
                    }
                } catch (e) {
                    // Cross-origin restrictions may prevent this, that's ok
                }
            }
        }
    }
    
    processDeploymentErrors(status) {
        // Process component failures
        if (status.componentFailures && status.componentFailures.length > 0) {
            this.deploymentErrors = status.componentFailures.map(failure => ({
                id: `error-${Math.random()}`,
                fileName: failure.fileName || 'Unknown',
                problem: failure.problem || 'Unknown error',
                lineNumber: failure.lineNumber || '',
                columnNumber: failure.columnNumber || ''
            }));
        }
        
        // Process test failures
        if (status.testFailures && status.testFailures.length > 0) {
            this.deploymentTestFailures = status.testFailures.map(failure => ({
                id: `test-${Math.random()}`,
                className: failure.name || 'Unknown',
                methodName: failure.methodName || 'Unknown',
                message: failure.message || 'Test failed',
                stackTrace: failure.stackTrace || ''
            }));
            
            // Check for validation rule conflicts
            const hasValidationError = status.testFailures.some(failure => 
                failure.message && failure.message.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')
            );
            
            if (hasValidationError) {
                this.showStickyToast(
                    'Validation Rule Conflict', 
                    'Validation Rule Conflict detected. Please disable the rule and try again.',
                    'error'
                );
            }
        }
        
        this.showToast('Deployment Failed', 'Check the error details below', 'error');
    }
    
    showStickyToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode: 'sticky' // User must dismiss manually
            })
        );
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
                cardAriaLabel: `${card.objectName} - ${card.fieldCount} unique fields, ${card.totalMappings} total mappings`,
                viewDetailsAriaLabel: `View field mapping details for ${card.objectName}`,
                deployAriaLabel: `Deploy trigger for ${card.objectName}`
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
    
    get hasDeploymentErrors() {
        return this.deploymentErrors && this.deploymentErrors.length > 0;
    }
    
    get hasTestFailures() {
        return this.deploymentTestFailures && this.deploymentTestFailures.length > 0;
    }
    
    get deploymentFailed() {
        return this.deploymentStatus && this.deploymentStatus.status !== 'Succeeded';
    }

    async deploy() {
        this.isBusy = true;
        this.message = '';
        // Clear previous deployment status
        this.deploymentStatus = null;
        this.deploymentErrors = [];
        this.deploymentTestFailures = [];
        this.showDeploymentStatus = false;
        
        try {
            // Open VF page in a new window for JSZip-based deployment
            const vfUrl = `/apex/DateBuddyDeploy?objectApiName=${encodeURIComponent(this.objectApiName)}`;
            const deployWindow = window.open(vfUrl, 'deployWindow', 'width=600,height=400');
            
            // Store window reference for later use
            this.deploymentWindow = deployWindow;
            
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
        let attempts = 0;
        const maxAttempts = 30; // ~30s
        const intervalMs = 1000;
        this.clearPoll();
        this.pollTimer = setInterval(async () => {
            attempts++;
            try {
                const status = await getStatus({ asyncId });
                this.message = `Status: ${status.state}${status.message ? ' — ' + status.message : ''}`;
                if (status.done || attempts >= maxAttempts) {
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
                        if (isSuccess) {
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
                    } else if (attempts >= maxAttempts) {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Deployment Timed Out',
                                message: 'Stopped polling after ~30s. Check status later.',
                                variant: 'warning'
                            })
                        );
                        this.canRetry = true;
                    }
                    this.clearPoll();
                }
            } catch (e) {
                this.message = e?.body?.message || e?.message || 'Status check failed';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Status Check Error',
                        message: this.message,
                        variant: 'error'
                    })
                );
                this.canRetry = true;
                this.clearPoll();
            }
        }, intervalMs);
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
