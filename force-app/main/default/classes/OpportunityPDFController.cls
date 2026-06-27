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
            if (!Schema.sObjectType.Opportunity.isAccessible()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You do not have access to Opportunity.'));
                return;
            }

            List<Opportunity> oppList = [
                SELECT Id, Name, Invoice_Number__c, AccountId, Account.Name, Amount, CloseDate, Owner.Name
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            if (!oppList.isEmpty()) {
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, oppList);
                this.opp = (Opportunity) decision.getRecords()[0];
            } else {
                this.opp = null;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Opportunity not found.'));
            }

            if (!Schema.sObjectType.Organization.isAccessible()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You do not have access to Organization.'));
            } else {
                List<Organization> orgList = [
                    SELECT Name, Street, City, State, PostalCode, Country, Phone
                    FROM Organization
                    LIMIT 1
                ];
                if (!orgList.isEmpty()) {
                    SObjectAccessDecision orgDecision = Security.stripInaccessible(AccessType.READABLE, orgList);
                    this.myOrg = (Organization) orgDecision.getRecords()[0];
                }
            }

            if (!Schema.sObjectType.OpportunityContactRole.isAccessible()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'You do not have access to Opportunity Contact Role.'));
                this.primaryContact = null;
            } else {
                List<OpportunityContactRole> contactRoles = [
                    SELECT Contact.Name, Contact.Email, Contact.Phone,
                           Contact.MailingStreet, Contact.MailingCity, Contact.MailingState,
                           Contact.MailingPostalCode, Contact.MailingCountry
                    FROM OpportunityContactRole
                    WHERE OpportunityId = :oppId AND IsPrimary = TRUE
                    LIMIT 1
                ];
                if (!contactRoles.isEmpty()) {
                    SObjectAccessDecision contactDecision = Security.stripInaccessible(AccessType.READABLE, contactRoles);
                    this.primaryContact = (OpportunityContactRole) contactDecision.getRecords()[0];
                }
            }

            if (!Schema.sObjectType.OpportunityLineItem.isAccessible()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'You do not have access to Opportunity Products.'));
                this.products = new List<OpportunityLineItem>();
            } else {
                List<OpportunityLineItem> productList = [
                    SELECT Product2.Name, Quantity, UnitPrice, TotalPrice, ServiceDate
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :oppId
                ];
                SObjectAccessDecision productDecision = Security.stripInaccessible(AccessType.READABLE, productList);
                this.products = (List<OpportunityLineItem>) productDecision.getRecords();
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unexpected error: ' + e.getMessage()));
        }
    }
}