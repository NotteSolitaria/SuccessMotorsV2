@IsTest
private class AccountSummaryControllerTest {

    @TestSetup
    static void setupData() {
        Account acc1 = new Account(Name = 'Acme Corporation');
        Account acc2 = new Account(Name = 'Beta LLC');
        insert new List<Account>{acc1, acc2};

        Opportunity oppClosedWon1 = new Opportunity(
            Name = 'Acme - Big Deal',
            AccountId = acc1.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 5000
        );
        Opportunity oppProgress = new Opportunity(
            Name = 'Acme - In Progress',
            AccountId = acc1.Id,
            StageName = 'Qualification', 
            CloseDate = Date.today(),
            Amount = 2000
        );
        
        Opportunity oppClosedWon2 = new Opportunity(
            Name = 'Beta - Small Deal',
            AccountId = acc2.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 1000
        );
        insert new List<Opportunity>{oppClosedWon1, oppProgress, oppClosedWon2};

        Product2 prod = new Product2(
            Name = 'Cloud Service', 
            IsActive = true
        );
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 2500,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = oppClosedWon1.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 2500
        );
        insert oli;
    }

    @IsTest
    static void testGetAccountDataByRecordId() {
        Account targetAcc = [SELECT Id FROM Account WHERE Name = 'Acme Corporation' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = AccountSummaryController.getAccountData(targetAcc.Id, null, null, 1);
        Test.stopTest();

        System.assertNotEquals(null, result, 'The result must not be null.');
        System.assertEquals(1, result.get('totalCount'), 'Only 1 account should be found');

        List<AccountSummaryController.AccountWrapper> records = (List<AccountSummaryController.AccountWrapper>) result.get('records');
        System.assertEquals(1, records.size(), 'The list of entries must contain 1 wrapper');
        
        AccountSummaryController.AccountWrapper wrapper = records[0];
        System.assertEquals('Acme Corporation', wrapper.accountName);
        System.assertEquals(5000, wrapper.totalClosedWon, 'The amount should only take into account Closed Won transactions');
        System.assertEquals(1, wrapper.opportunities.size(), 'Only 1 closed trade should be selected');
    }

    @IsTest
    static void testGetAccountDataBySearchTerm() {
        Test.startTest();
        Map<String, Object> result = AccountSummaryController.getAccountData(null, 'Beta', null, 1);
        Test.stopTest();

        System.assertEquals(1, result.get('totalCount'), '1 account must be found for the search query');
        
        List<AccountSummaryController.AccountWrapper> records = (List<AccountSummaryController.AccountWrapper>) result.get('records');
        System.assertEquals(1, records.size());
        System.assertEquals('Beta LLC', records[0].accountName);
    }

    @IsTest
    static void testGetAccountDataWithMinAmountFilter() {
        Test.startTest();

        Map<String, Object> result = AccountSummaryController.getAccountData(null, null, 3000.0, 1);
        Test.stopTest();

        System.assertEquals(2, result.get('totalCount'), 'The countQuery query finds both accounts.');
        
        List<AccountSummaryController.AccountWrapper> records = (List<AccountSummaryController.AccountWrapper>) result.get('records');
        System.assertEquals(1, records.size(), 'Only one account should be included in the resulting list.');
        System.assertEquals('Acme Corporation', records[0].accountName, 'Only the Acme account should remain');
    }

    @IsTest
    static void testGetOpportunityProducts() {
        Opportunity targetOpp = [SELECT Id FROM Opportunity WHERE Name = 'Acme - Big Deal' LIMIT 1];

        Test.startTest();
        List<OpportunityLineItem> products = AccountSummaryController.getOpportunityProducts(targetOpp.Id);
        Test.stopTest();

        System.assertNotEquals(null, products, 'The product list must not be null.');
        System.assertEquals(1, products.size(), 'Must return 1 product for this deal');
        System.assertEquals('Cloud Service', products[0].Product2.Name, 'The product name must match the one created in setup');
    }
}