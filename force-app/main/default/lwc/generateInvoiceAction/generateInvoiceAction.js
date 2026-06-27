import { LightningElement, api } from 'lwc';
import generateAndAttachInvoice from '@salesforce/apex/InvoiceFileService.generateAndAttachInvoice';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class GenerateInvoice extends LightningElement {
    @api recordId;

    @api invoke() {
        generateAndAttachInvoice({ recordId: this.recordId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Invoice PDF was generated and attached to the Opportunity.',
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error?.body?.message || 'Failed to generate invoice.',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }
}