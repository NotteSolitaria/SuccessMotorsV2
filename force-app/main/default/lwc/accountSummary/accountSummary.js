import { LightningElement, api, track, wire } from 'lwc';
import getAccountData from '@salesforce/apex/AccountSummaryController.getAccountData';
import getOpportunityProducts from '@salesforce/apex/AccountSummaryController.getOpportunityProducts';

const OPP_COLUMNS = [
    { 
        label: 'Opportunity Name', 
        fieldName: 'oppLink', 
        type: 'url', 
        typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' } 
    },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
    { label: 'Close Date', fieldName: 'CloseDate', type: 'date' },
    { label: 'Amount', fieldName: 'Amount', type: 'currency' },
    {
        type: 'button',
        typeAttributes: { 
            label: 'View Products', 
            name: 'view_products', 
            variant: 'brand-outline' 
        }
    }
];

const PROD_COLUMNS = [
    { label: 'Product Name', fieldName: 'ProductName' },
    { label: 'Quantity', fieldName: 'Quantity', type: 'number' },
    { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency' },
    { label: 'Total Price', fieldName: 'TotalPrice', type: 'currency' }
];

export default class AccountSummary extends LightningElement {
    @api recordId;

    @track accountData = [];
    @track oppColumns = OPP_COLUMNS;
    @track prodColumns = PROD_COLUMNS;
    
    searchTerm = '';
    minAmount = null;
    pageNumber = 1;
    totalRecords = 0;

    isModalOpen = false;
    @track modalProducts = [];
    isLoadingProducts = false;

    get isTabContext() {
        return !this.recordId;
    }

    get isFirstPage() { return this.pageNumber === 1; }
    get isLastPage() { return (this.pageNumber * 10) >= this.totalRecords; }

    connectedCallback() {
        this.fetchData();
    }

    fetchData() {
        getAccountData({ 
            recordId: this.recordId, 
            searchTerm: this.searchTerm, 
            minAmount: this.minAmount, 
            pageNumber: this.pageNumber 
        })
        .then(result => {
            this.accountData = result.records.map(acc => {
                let mappedOpps = acc.opportunities.map(opp => {
                    return { ...opp, oppLink: `/${opp.Id}` };
                });
                return {
                    ...acc,
                    accordionLabel: `${acc.accountName} (Total: $${acc.totalClosedWon || 0})`,
                    opportunities: mappedOpps
                };
            });
            this.totalRecords = result.totalCount;
        })
        .catch(error => {
            console.error('Error fetching data', error);
        });
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.pageNumber = 1; 
        this.fetchData();
    }

    handleAmountChange(event) {
        this.minAmount = event.target.value ? parseFloat(event.target.value) : null;
        this.pageNumber = 1;
        this.fetchData();
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.fetchData();
        }
    }

    handleNext() {
        this.pageNumber++;
        this.fetchData();
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'view_products') {
            this.openModal(row.Id);
        }
    }

    openModal(opportunityId) {
        this.isModalOpen = true;
        this.isLoadingProducts = true;
        
        getOpportunityProducts({ opportunityId: opportunityId })
            .then(result => {
                this.modalProducts = result.map(prod => {
                    return { ...prod, ProductName: prod.Product2.Name };
                });
            })
            .catch(error => console.error(error))
            .finally(() => { this.isLoadingProducts = false; });
    }

    closeModal() {
        this.isModalOpen = false;
        this.modalProducts = [];
    }
}