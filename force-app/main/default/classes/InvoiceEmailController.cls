public with sharing class InvoiceEmailController {

    private static final String TEMPLATE_DEVELOPER_NAME = 'Invoice_Email';

    public class InvoiceEmailData {
        @AuraEnabled public String subject;
        @AuraEnabled public String body;
        @AuraEnabled public String recipientName;
        @AuraEnabled public String recipientEmail;
        @AuraEnabled public String previewUrl;
        @AuraEnabled public String invoiceNumber;
    }

    @AuraEnabled(cacheable=true)
    public static InvoiceEmailData getEmailData(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        try {
            Opportunity opp = getOpportunityData(opportunityId);

            if (String.isBlank(opp.Invoice_Number__c)) {
                throw new AuraHandledException('Invoice Number is not available. Generate an invoice first.');
            }

            EmailTemplate template = [
                SELECT Id, Subject, Body, HtmlValue
                FROM EmailTemplate
                WHERE DeveloperName = :TEMPLATE_DEVELOPER_NAME
                LIMIT 1
            ];

            Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(
                template.Id,
                UserInfo.getUserId(),
                opportunityId
            );

            OpportunityContactRole primaryRole = opp.OpportunityContactRoles.isEmpty() ? null : opp.OpportunityContactRoles[0];
            Id contentDocumentId = findLinkedInvoiceDocumentId(opp);

            InvoiceEmailData data = new InvoiceEmailData();
            data.subject = renderedEmail.getSubject();
            data.body = String.isNotBlank(renderedEmail.getPlainTextBody())
                ? renderedEmail.getPlainTextBody()
                : renderedEmail.getHtmlBody();
            data.recipientName = primaryRole != null ? primaryRole.Contact.Name : '';
            data.recipientEmail = primaryRole != null ? primaryRole.Contact.Email : '';
            data.invoiceNumber = opp.Invoice_Number__c;
            data.previewUrl = contentDocumentId != null
                ? '/sfc/servlet.shepherd/document/download/' + contentDocumentId
                : null;

            return data;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load email data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendInvoiceEmail(Id opportunityId, String subject, String body) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required.');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Email subject is required.');
        }
        if (String.isBlank(body)) {
            throw new AuraHandledException('Email body is required.');
        }

        try {
            Opportunity opp = getOpportunityData(opportunityId);

            OpportunityContactRole primaryRole = opp.OpportunityContactRoles.isEmpty() ? null : opp.OpportunityContactRoles[0];
            if (primaryRole == null || String.isBlank(primaryRole.Contact.Email)) {
                throw new AuraHandledException('Primary contact with a valid email address was not found.');
            }

            Id contentDocumentId = findLinkedInvoiceDocumentId(opp);
            if (contentDocumentId == null) {
                throw new AuraHandledException('Invoice PDF was not found. Use Generate Invoice first.');
            }

            ContentVersion latestVersion = [
                SELECT VersionData, PathOnClient
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId AND IsLatest = TRUE
                LIMIT 1
            ];

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(latestVersion.PathOnClient);
            attachment.setBody(latestVersion.VersionData);
            attachment.setContentType('application/pdf');

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ primaryRole.Contact.Email });
            email.setSubject(subject);
            email.setPlainTextBody(body);
            email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
            email.setWhatId(opportunityId);
            email.setSaveAsActivity(true);
            
            email.setReplyTo(getInboundEmailAddress());

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }

    private static Opportunity getOpportunityData(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT Id, Invoice_Number__c,
                (SELECT Contact.Name, Contact.Email 
                 FROM OpportunityContactRoles 
                 WHERE IsPrimary = TRUE LIMIT 1),
                (SELECT ContentDocumentId, ContentDocument.Title 
                 FROM ContentDocumentLinks)
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opps.isEmpty()) {
            throw new AuraHandledException('Opportunity not found.');
        }
        return opps[0];
    }

    private static Id findLinkedInvoiceDocumentId(Opportunity opp) {
        if (String.isBlank(opp.Invoice_Number__c) || opp.ContentDocumentLinks == null) {
            return null;
        }
        
        for (ContentDocumentLink link : opp.ContentDocumentLinks) {
            if (link.ContentDocument.Title == opp.Invoice_Number__c) {
                return link.ContentDocumentId;
            }
        }
        return null;
    }

    private static String getInboundEmailAddress() {
        try {
            ApexClass handlerClass = [
                SELECT Id 
                FROM ApexClass 
                WHERE Name = 'OrderConfirmationEmailHandler' 
                LIMIT 1
            ];

            EmailServicesFunction emailFunction = [
                SELECT Id 
                FROM EmailServicesFunction 
                WHERE ApexClassId = :handlerClass.Id 
                LIMIT 1
            ];

            EmailServicesAddress address = [
                SELECT LocalPart, EmailDomainName 
                FROM EmailServicesAddress 
                WHERE FunctionId = :emailFunction.Id 
                LIMIT 1
            ];

            return address.LocalPart + '@' + address.EmailDomainName;
        } catch (Exception e) {
            return UserInfo.getUserEmail();
        }
    }
}