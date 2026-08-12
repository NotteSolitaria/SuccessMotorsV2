public with sharing class InvoiceFileService {

    @AuraEnabled
    public static void generateAndAttachInvoice(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        try {
            Opportunity opp = [
                SELECT Id, Invoice_Number__c
                FROM Opportunity
                WHERE Id = :recordId
                LIMIT 1
            ];

            String invoiceName = opp.Invoice_Number__c;
            if (String.isBlank(invoiceName)) {
                throw new AuraHandledException('Invoice Number is empty. Save the Opportunity record first to generate the auto-number.');
            }

            PageReference pdfPage = Page.OpportunityInvoicePDF;
            pdfPage.getParameters().put('id', recordId);

            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = invoiceName;
            cv.PathOnClient = invoiceName + '.pdf';
            cv.VersionData = pdfBlob;
            cv.IsMajorVersion = true;

            cv.FirstPublishLocationId = recordId;
            insert cv;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create invoice: ' + e.getMessage());
        }
    }
}