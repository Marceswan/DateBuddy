import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deployTrigger from '@salesforce/apex/DateBuddyDeployController.deployTrigger';
import getStatus from '@salesforce/apex/DateBuddyDeployController.getStatus';
import listSObjects from '@salesforce/apex/DateBuddyDeployController.listSObjects';
import getTriggerSource from '@salesforce/apex/DateBuddyDeployController.getTriggerSource';

export default class DateBuddyTriggerDeployer extends LightningElement {
    @track objectApiName = '';
    @track isBusy = false;
    @track message = '';
    @track options = [];
    @track source = '';
    @track canRetry = false;
    pollTimer;

    async connectedCallback() {
        try {
            const names = await listSObjects();
            this.options = names.map(n => ({ label: n, value: n }));
        } catch (e) {
            this.message = e?.body?.message || e?.message || 'Failed to load objects';
        }
    }

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
