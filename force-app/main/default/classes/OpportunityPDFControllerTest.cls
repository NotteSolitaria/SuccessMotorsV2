@IsTest
private class OpportunityPDFControllerTest {

    @IsTest
    static void testControllerLoadsAllDataSuccessfully() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1000
        );
        insert opp;

        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            AccountId = acc.Id,
            MailingStreet = '123 Main St',
            MailingCity = 'Minsk',
            MailingPostalCode = '10001',
            MailingCountry = 'Belarus',
            Phone = '555-0100'
        );
        insert con;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        Product2 prod = new Product2(
            Name = 'Test Product', 
            IsActive = true
        );
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert oli;

        Test.setCurrentPage(Page.OpportunityInvoicePDF);
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        
        ApexPages.StandardController stdController = new ApexPages.StandardController(opp);

        Test.startTest();
        OpportunityPDFController controller = new OpportunityPDFController(stdController);
        Test.stopTest();

        System.assertNotEquals(null, controller.opp, 'Opportunity should load successfully.');
        System.assertEquals(opp.Id, controller.opp.Id, 'The ID of the downloaded Opportunity must match');
        
        System.assertNotEquals(null, controller.myOrg, 'Organization details must be uploaded');
        
        System.assertNotEquals(null, controller.primaryContact, 'Primary Contact must be found');
        System.assertEquals('John Doe', controller.primaryContact.Contact.Name, 'Contact name must match');
        
        System.assertNotEquals(null, controller.products, 'The product list must not be null.');
        System.assertEquals(1, controller.products.size(), 'There must be one product in the list.');
    }

    @IsTest
    static void testControllerHandlesMissingId() {
        Opportunity emptyOpp = new Opportunity();
        ApexPages.StandardController stdController = new ApexPages.StandardController(emptyOpp);

        Test.startTest();
        OpportunityPDFController controller = new OpportunityPDFController(stdController);
        Test.stopTest();

        System.assertEquals(null, controller.opp, 'Opportunity must be null if ID is not passed.');
        
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(!messages.isEmpty(), 'An error message should appear.');
        
        Boolean foundIdError = false;
        for (ApexPages.Message msg : messages) {
            if (msg.getSummary().contains('Opportunity ID is missing.')) {
                foundIdError = true;
                break;
            }
        }
        System.assert(foundIdError, 'Expected error message missing ID not found');
    }
}