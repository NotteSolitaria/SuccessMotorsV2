import { LightningElement, api, wire } from 'lwc';
import getEmailData from '@salesforce/apex/InvoiceEmailController.getEmailData';
import sendInvoiceEmail from '@salesforce/apex/InvoiceEmailController.sendInvoiceEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class SendInvoice extends LightningElement {
    @api recordId;

    subject = '';
    body = '';
    recipientName = '';
    previewUrl;
    isLoading = true;
    isSending = false;
    errorMessage;

    @wire(getEmailData, { opportunityId: '$recordId' })
    wiredEmailData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.subject = data.subject;
            this.body = data.body;
            this.recipientName = data.recipientName;
            this.previewUrl = data.previewUrl;
            this.errorMessage = undefined;
        } else if (error) {
            this.errorMessage = error?.body?.message || 'Failed to load email data.';
        }
    }

    handleBodyChange(event) {
        this.body = event.target.value;
    }

    handlePreview() {
        if (!this.previewUrl) {
            this.showToast('Warning', 'Invoice PDF was not found. Use Generate Invoice first.', 'warning');
            return;
        }
        window.open(this.previewUrl, '_blank');
    }

    handleSend() {
        this.isSending = true;
        sendInvoiceEmail({
            opportunityId: this.recordId,
            subject: this.subject,
            body: this.body
        })
            .then(() => {
                this.showToast('Success', 'Invoice email was sent successfully.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                this.showToast('Error', error?.body?.message || 'Failed to send email.', 'error');
            })
            .finally(() => {
                this.isSending = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get isSendDisabled() {
        return this.isLoading || this.isSending || !!this.errorMessage;
    }

    get isPreviewDisabled() {
        return !this.previewUrl;
    }
}