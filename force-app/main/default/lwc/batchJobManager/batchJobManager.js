import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobStatus from '@salesforce/apex/BatchJobManagerController.getJobStatus';
import runBatchNow from '@salesforce/apex/BatchJobManagerController.runBatchNow';
import scheduleJob from '@salesforce/apex/BatchJobManagerController.scheduleJob';
import abortScheduledJob from '@salesforce/apex/BatchJobManagerController.abortScheduledJob';

export default class BatchJobManager extends LightningElement {
    @api 
    cardTitle = 'Campaign management and Planner';
    @api 
    batchClassName = 'ContactBirthdayBatch';
    @api 
    schedulerClassName = 'ContactBirthdayScheduler';
    @api 
    jobName = 'Daily Birthday Congratulations';
    @api 
    cronExpression = '0 0 0 * * ?';

    @track jobStatus = {};
    isLoading = false;

    connectedCallback() {
        this.fetchJobStatus();
    }

    async fetchJobStatus() {
        this.isLoading = true;
        try {
            this.jobStatus = await getJobStatus({
                batchClassName: this.batchClassName,
                schedulerClassName: this.schedulerClassName,
                jobName: this.jobName
            });
        } catch (error) {
            this.showToast('Error:', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRunOnce() {
        this.isLoading = true;
        try {
            const jobId = await runBatchNow({ batchClassName: this.batchClassName, scopeSize: 200 });
            this.showToast('Success', `The batch is running. Job ID: ${jobId}`, 'success');
            await this.fetchJobStatus();
        } catch (error) {
            this.showToast('Launch error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSchedule() {
        this.isLoading = true;
        try {
            const jobId = await scheduleJob({
                schedulerClassName: this.schedulerClassName,
                jobName: this.jobName,
                cronExpression: this.cronExpression
            });
            this.showToast('Success', `The scheduler is running. Job ID: ${jobId}`, 'success');
            await this.fetchJobStatus();
        } catch (error) {
            this.showToast('Schedule error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleAbort() {
        if (!this.jobStatus.cronJobId) return;
        this.isLoading = true;
        try {
            await abortScheduledJob({ jobId: this.jobStatus.cronJobId });
            this.showToast('Cancelled', 'Scheduled task cancelled', 'warning');
            await this.fetchJobStatus();
        } catch (error) {
            this.showToast('Cancellation error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleBatchClassChange(e) { this.batchClassName = e.target.value; }
    handleSchedulerClassChange(e) { this.schedulerClassName = e.target.value; }
    handleJobNameChange(e) { this.jobName = e.target.value; }
    handleCronChange(e) { this.cronExpression = e.target.value; }

    get formattedNextFireTime() {
        return this.jobStatus.nextFireTime ? new Date(this.jobStatus.nextFireTime).toLocaleString() : '-';
    }

    get formattedPreviousFireTime() {
        return this.jobStatus.previousFireTime ? new Date(this.jobStatus.previousFireTime).toLocaleString() : '-';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}