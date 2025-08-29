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
        { label: 'Entry Date Field', fieldName: 'entryDateField', type: 'text' },
        { label: 'Exit Date Field', fieldName: 'exitDateField', type: 'text' },
        { label: 'Direction', fieldName: 'direction', type: 'text' }
    ];
    
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
                cardAriaLabel: `${card.objectLabel} (${card.objectApiName}) - ${card.uniqueFieldsCount} unique fields, ${card.totalMappingsCount} total mappings, ${card.hasDeployedTrigger ? 'trigger deployed' : 'no trigger deployed'}`,
                viewDetailsAriaLabel: `View field mapping details for ${card.objectLabel}`,
                deployAriaLabel: `${card.hasDeployedTrigger ? 'Re-deploy' : 'Deploy'} trigger for ${card.objectLabel}`
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
            this.treeData = cachedData.treeData;
            this.tableData = cachedData.tableData;
            return;
        }

        this.isLoadingModal = true;
        this.modalErrorMessage = '';
        try {
            const fieldMappings = await getObjectFieldMappings({ objectApiName });
            this.treeData = fieldMappings.treeData || [];
            this.tableData = fieldMappings.mappingDetails || [];
            
            // Cache the data
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
