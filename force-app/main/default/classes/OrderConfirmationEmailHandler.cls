public class OrderConfirmationEmailHandler implements Messaging.InboundEmailHandler {

  public Messaging.InboundEmailResult handleInboundEmail(
    Messaging.InboundEmail email,
    Messaging.InboundEnvelope envelope
  ) {
    Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

    String body = String.isNotBlank(email.plainTextBody)
      ? email.plainTextBody
      : email.htmlBody;

    String orderNumber = extractOrderNumber(email.subject, body);

    if (String.isBlank(orderNumber)) {
      result.success = true; 
      return result;
    }

    List<Opportunity> opps = [
      SELECT Id, StageName
      FROM Opportunity
      WHERE Invoice_Number__c = :orderNumber
      LIMIT 1
    ];

    if (opps.isEmpty()) {
      result.success = true;
      return result;
    }

    Opportunity opp = opps[0];
    
    List<Schema.PicklistEntry> stageValues = Opportunity.StageName.getDescribe().getPicklistValues();
    
    for (Integer i = 0; i < stageValues.size() - 1; i++) {
      if (stageValues[i].getValue() == opp.StageName) {
        opp.StageName = stageValues[i + 1].getValue();
        break;
      }
    }

    update opp;

    result.success = true;
    return result;
  }

  private static String extractOrderNumber(String subject, String body) {
    String text = (subject + ' ' + body).toUpperCase();
    Pattern p = Pattern.compile('INV-\\d+');
    Matcher m = p.matcher(text);
    return m.find() ? m.group() : null;
  }
}