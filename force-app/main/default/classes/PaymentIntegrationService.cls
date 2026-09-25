@RestResource(urlMapping='/Payments/*')
global with sharing class PaymentIntegrationService {

    @HttpPost
    global static String createPayments() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            String requestBody = req.requestBody.toString();
            
            PaymentRequestWrapper wrapper = (PaymentRequestWrapper) JSON.deserialize(requestBody, PaymentRequestWrapper.class);
            
            List<Payment__c> paymentsToInsert = new List<Payment__c>();
            
            if (wrapper.payments != null && !wrapper.payments.isEmpty()) {
                for (PaymentInfo info : wrapper.payments) {
                    Payment__c newPayment = new Payment__c();
                    newPayment.OpportunityName__c = info.Opportunity;
                    newPayment.Amount__c = info.Amount;
                    newPayment.FirstName__c = info.FirstName;
                    newPayment.LastName__c = info.LastName;
                    
                    paymentsToInsert.add(newPayment);
                }
            }
            
            if (!paymentsToInsert.isEmpty()) {
                insert paymentsToInsert;
            }
            
            res.statusCode = 201;
            return 'Success: ' + paymentsToInsert.size() + ' payment records created.';
            
        } catch (Exception e) {
            res.statusCode = 500;
            return 'Error: ' + e.getMessage();
        }
    }

    global class PaymentRequestWrapper {
        global List<PaymentInfo> payments;
    }
    
    global class PaymentInfo {
        global String Opportunity;
        global Decimal Amount;
        global String FirstName;
        global String LastName;
    }
}