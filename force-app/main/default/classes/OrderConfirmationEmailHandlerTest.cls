@IsTest
private class OrderConfirmationEmailHandlerTest {
    @IsTest
    static void approvedMovesToNextStage() {
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;

        testOpp = [SELECT Invoice_Number__c FROM Opportunity WHERE Id = :testOpp.Id];
        String invoiceNumber = testOpp.Invoice_Number__c;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Re: Invoice ' + invoiceNumber;
        email.plainTextBody = 'Approved';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        new OrderConfirmationEmailHandler().handleInboundEmail(email, envelope);
        Test.stopTest();

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :testOpp.Id];
        System.assertEquals('Negotiation/Review', updated.StageName);
    }
}