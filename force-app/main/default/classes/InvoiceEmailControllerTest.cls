@IsTest
private class InvoiceEmailControllerTest {

    @TestSetup
    static void setupData() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(thisUser) {
            EmailTemplate template = new EmailTemplate(
                DeveloperName = 'Invoice_Email',
                TemplateType = 'text',
                FolderId = UserInfo.getUserId(),
                Name = 'Invoice Email Template',
                Subject = 'Invoice Subject',
                Body = 'Invoice Body'
            );
            insert template;
        }

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            AccountId = acc.Id
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

        opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :opp.Id LIMIT 1];

        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            IsPrimary = true
        );
        insert ocr;

        String docTitle = String.isNotBlank(opp.Invoice_Number__c) ? opp.Invoice_Number__c : 'Dummy_Invoice';

        ContentVersion cv = new ContentVersion(
            Title = docTitle,
            PathOnClient = docTitle + '.pdf',
            VersionData = Blob.valueOf('Fake PDF Data'),
            IsMajorVersion = true
        );
        insert cv;

        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = conDocId,
            ShareType = 'V'
        );
        insert cdl;
    }

    @IsTest
    static void testGetEmailData_Success() {
        Opportunity opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];

        Test.startTest();
        InvoiceEmailController.InvoiceEmailData data = InvoiceEmailController.getEmailData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, data, 'Data should not be null');
        System.assertEquals(opp.Invoice_Number__c, data.invoiceNumber, 'Invoice number should match');
        System.assertEquals('Test Contact', data.recipientName, 'Recipient name should match');
        System.assertEquals('test@example.com', data.recipientEmail, 'Recipient email should match');
        System.assertEquals('Invoice Subject', data.subject, 'Subject should match template');
        System.assert(data.previewUrl.contains('/sfc/servlet.shepherd/document/download/'), 'Preview URL should be populated');
    }

    @IsTest
    static void testGetEmailData_NullId() {
        Test.startTest();
        try {
            InvoiceEmailController.getEmailData(null);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Opportunity ID is required.'), 'Incorrect exception message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetEmailData_NoInvoiceNumber() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity oppWithoutInvoice = new Opportunity(
            Name = 'Test Opp No Invoice',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert oppWithoutInvoice;
        
        oppWithoutInvoice = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :oppWithoutInvoice.Id];

        if (String.isNotBlank(oppWithoutInvoice.Invoice_Number__c)) {
            return;
        }

        Test.startTest();
        try {
            InvoiceEmailController.getEmailData(oppWithoutInvoice.Id);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Invoice Number is not available.'), 'Incorrect exception message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendInvoiceEmail_Success() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];

        Test.startTest();
        InvoiceEmailController.sendInvoiceEmail(opp.Id, 'Test Subject', 'Test Body');
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailInvocations, 'One email should have been sent');
    }

    @IsTest
    static void testSendInvoiceEmail_ValidationErrors() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];

        Test.startTest();
        
        try {
            InvoiceEmailController.sendInvoiceEmail(opp.Id, '', 'Body');
            System.assert(false, 'Expected exception for empty subject');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Email subject is required.'));
        }

        try {
            InvoiceEmailController.sendInvoiceEmail(opp.Id, 'Subject', null);
            System.assert(false, 'Expected exception for empty body');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Email body is required.'));
        }

        Test.stopTest();
    }

    @IsTest
    static void testSendInvoiceEmail_NoPrimaryContact() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];
        
        delete [SELECT Id FROM OpportunityContactRole WHERE OpportunityId = :opp.Id];

        Test.startTest();
        try {
            InvoiceEmailController.sendInvoiceEmail(opp.Id, 'Subj', 'Body');
            System.assert(false, 'Expected exception for missing contact');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Primary contact with a valid email address was not found.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendInvoiceEmail_NoDocumentLinked() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];
        
        delete [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id];

        Test.startTest();
        try {
            InvoiceEmailController.sendInvoiceEmail(opp.Id, 'Subj', 'Body');
            System.assert(false, 'Expected exception for missing document');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Invoice PDF was not found.'));
        }
        Test.stopTest();
    }
}