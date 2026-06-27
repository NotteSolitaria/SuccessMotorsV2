@IsTest
private class InvoiceFileServiceTest {

    @IsTest
    static void generateAndAttachInvoiceCreatesFile() {
        Account acc = new Account(Name = 'Invoice Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Invoice Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Amount = 500
        );
        insert opp;

        opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :opp.Id];

        Test.startTest();
        InvoiceFileService.generateAndAttachInvoice(opp.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opp.Id
        ];

        System.assertEquals(1, links.size());
        System.assertEquals(opp.Invoice_Number__c, links[0].ContentDocument.Title);
    }

    @IsTest
    static void generateAndAttachInvoiceCreatesNewVersion() {
        Account acc = new Account(Name = 'Version Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Version Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Amount = 500
        );
        insert opp;

        opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :opp.Id];

        Test.startTest();
        InvoiceFileService.generateAndAttachInvoice(opp.Id);
        InvoiceFileService.generateAndAttachInvoice(opp.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opp.Id
        ];

        List<ContentVersion> versions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
        ];

        System.assertEquals(1, links.size());
        System.assertEquals(2, versions.size());
    }
}