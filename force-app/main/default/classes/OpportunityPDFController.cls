public with sharing class OpportunityPDFController {

    public Opportunity opp { get; private set; }
    public Organization myOrg { get; private set; }
    public OpportunityContactRole primaryContact { get; private set; }
    public List<OpportunityLineItem> products { get; private set; }

    public OpportunityPDFController(ApexPages.StandardController stdController) {
        Id oppId = stdController.getId();
        if (oppId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Opportunity ID is missing.'));
            return;
        }

        try {
            List<Opportunity> oppList = [
                SELECT Id, Name, Invoice_Number__c, AccountId, Account.Name, Amount, CloseDate, Owner.Name
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            if (!oppList.isEmpty()) {
                this.opp = oppList[0];
            } else {
                this.opp = null;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Opportunity not found.'));
                return;
            }

            List<Organization> orgList = [
                SELECT Name, Street, City, State, PostalCode, Country, Phone
                FROM Organization
                LIMIT 1
            ];
            if (!orgList.isEmpty()) {
                this.myOrg = orgList[0];
            }

            List<OpportunityContactRole> contactRoles = [
                SELECT Contact.Name, Contact.Email, Contact.Phone,
                        Contact.MailingStreet, Contact.MailingCity, Contact.MailingState,
                        Contact.MailingPostalCode, Contact.MailingCountry
                FROM OpportunityContactRole
                WHERE OpportunityId = :oppId AND IsPrimary = TRUE
                LIMIT 1
            ];
            if (!contactRoles.isEmpty()) {
                this.primaryContact = contactRoles[0];
            }

            this.products = [
                SELECT Product2.Name, Quantity, UnitPrice, TotalPrice, ServiceDate
                FROM OpportunityLineItem
                WHERE OpportunityId = :oppId
            ];
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unexpected error: ' + e.getMessage()));
        }
    }
}