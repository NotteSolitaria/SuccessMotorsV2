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
            Opportunity opp = [
                SELECT Id, Invoice_Number__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

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

            OpportunityContactRole primaryRole = getPrimaryContactRole(opportunityId);
            Id contentDocumentId = findLinkedInvoiceDocumentId(opportunityId, opp.Invoice_Number__c);

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
            Opportunity opp = [
                SELECT Id, Invoice_Number__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            OpportunityContactRole primaryRole = getPrimaryContactRole(opportunityId);
            if (primaryRole == null || String.isBlank(primaryRole.Contact.Email)) {
                throw new AuraHandledException('Primary contact with a valid email address was not found.');
            }

            Id contentDocumentId = findLinkedInvoiceDocumentId(opportunityId, opp.Invoice_Number__c);
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

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }

    private static OpportunityContactRole getPrimaryContactRole(Id opportunityId) {
        List<OpportunityContactRole> roles = [
            SELECT Contact.Name, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId AND IsPrimary = TRUE
            LIMIT 1
        ];
        return roles.isEmpty() ? null : roles[0];
    }

    private static Id findLinkedInvoiceDocumentId(Id recordId, String invoiceName) {
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            if (link.ContentDocument.Title == invoiceName) {
                return link.ContentDocumentId;
            }
        }
        return null;
    }
}