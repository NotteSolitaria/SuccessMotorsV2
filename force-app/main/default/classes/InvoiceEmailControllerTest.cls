@IsTest
private class InvoiceEmailControllerTest {

    @IsTest
    static void getEmailDataReturnsRenderedTemplate() {
        Account acc = new Account(Name = 'Email Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Email Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            Amount = 750
        );
        insert opp;

        Contact con = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com',
            AccountId = acc.Id
        );
        insert con;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        Test.startTest();
        InvoiceFileService.generateAndAttachInvoice(opp.Id);
        InvoiceEmailController.InvoiceEmailData data = InvoiceEmailController.getEmailData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, data.subject);
        System.assert(data.subject.contains('Invoice'));
        System.assertEquals('Jane Smith', data.recipientName);
        System.assertNotEquals(null, data.previewUrl);
    }

    @IsTest
    static void sendInvoiceEmailSendsMessage() {
        Account acc = new Account(Name = 'Send Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Send Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            Amount = 750
        );
        insert opp;

        Contact con = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com',
            AccountId = acc.Id
        );
        insert con;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        InvoiceFileService.generateAndAttachInvoice(opp.Id);
        InvoiceEmailController.InvoiceEmailData data = InvoiceEmailController.getEmailData(opp.Id);

        Test.startTest();
        InvoiceEmailController.sendInvoiceEmail(opp.Id, data.subject, data.body);
        Test.stopTest();

        System.assertEquals(1, Limits.getEmailInvocations());
    }
}