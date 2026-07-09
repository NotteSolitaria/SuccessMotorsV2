public with sharing class AccountSummaryController {
    
    public class AccountWrapper {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Decimal totalClosedWon { get; set; }
        @AuraEnabled public List<Opportunity> opportunities { get; set; }
        
        public AccountWrapper(Account acc, List<Opportunity> opps, Decimal total) {
            this.accountId = acc.Id;
            this.accountName = acc.Name;
            this.opportunities = opps;
            this.totalClosedWon = total;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAccountData(Id recordId, String searchTerm, Decimal minAmount, Integer pageNumber) {
        Integer pageSize = 10;
        Integer offsetValue = calculateOffset(pageNumber, pageSize);
        
        String baseQuery = 'SELECT Id, Name, (SELECT Id, Name, CreatedDate, CloseDate, Amount, StageName FROM Opportunities WHERE IsClosed = true AND IsWon = true) FROM Account';
        String countQuery = 'SELECT count() FROM Account';
        
        String whereClause = buildWhereClause(recordId, searchTerm);
        
        String query = baseQuery + whereClause + ' ORDER BY Name LIMIT ' + pageSize + ' OFFSET ' + offsetValue;
        countQuery += whereClause;

        List<Account> accounts = Database.query(query);
        Integer totalRecords = Database.countQuery(countQuery);
        
        List<AccountWrapper> wrappers = buildWrappers(accounts, minAmount);

        return new Map<String, Object>{
            'records' => wrappers,
            'totalCount' => totalRecords
        };
    }

    private static Integer calculateOffset(Integer pageNumber, Integer pageSize) {
        if (pageNumber == null || pageNumber < 1) {
            pageNumber = 1;
        }
        return (pageNumber - 1) * pageSize;
    }

    private static String buildWhereClause(Id recordId, String searchTerm) {
        List<String> conditions = new List<String>();

        if (String.isNotBlank(recordId)) {
            conditions.add('Id = \'' + String.escapeSingleQuotes(recordId) + '\'');
        } else if (String.isNotBlank(searchTerm)) {
            conditions.add('Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'');
        }

        if (!conditions.isEmpty()) {
            return ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        return '';
    }

    private static List<AccountWrapper> buildWrappers(List<Account> accounts, Decimal minAmount) {
        List<AccountWrapper> wrappers = new List<AccountWrapper>();
        
        for (Account acc : accounts) {
            Decimal total = 0;
            List<Opportunity> validOpps = new List<Opportunity>();
            
            for (Opportunity opp : acc.Opportunities) {
                if (opp.Amount != null) {
                    total += opp.Amount;
                }
                validOpps.add(opp);
            }
            
            if (minAmount == null || total >= minAmount) {
                wrappers.add(new AccountWrapper(acc, validOpps, total));
            }
        }
        
        return wrappers;
    }

    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getOpportunityProducts(Id opportunityId) {
        return [
            SELECT Id, Product2.Name, Quantity, UnitPrice, TotalPrice 
            FROM OpportunityLineItem 
            WHERE OpportunityId = :opportunityId
        ];
    }
}