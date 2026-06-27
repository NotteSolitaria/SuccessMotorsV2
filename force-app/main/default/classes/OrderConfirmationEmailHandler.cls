public class OrderConfirmationEmailHandler implements Messaging.InboundEmailHandler {

  private static final String STAGE_AWAITING = 'Negotiation/Review';
  private static final String STAGE_APPROVED  = 'Closed Won'; 
  private static final String STAGE_REJECTED  = 'Closed Lost';

  public Messaging.InboundEmailResult handleInboundEmail(
    Messaging.InboundEmail email,
    Messaging.InboundEnvelope envelope
  ) {
    Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

    String body = String.isNotBlank(email.plainTextBody)
      ? email.plainTextBody
      : email.htmlBody;

    String orderNumber = extractOrderNumber(email.subject, body);
    String decision = extractDecision(body);

    if (String.isBlank(orderNumber) || String.isBlank(decision)) {
      result.success = true; 
      return result;
    }

    List<Opportunity> opps = [
      SELECT Id, StageName
      FROM Opportunity
      WHERE Invoice_Number__c = :orderNumber
      LIMIT 1
    ];

    if (opps.isEmpty() || opps[0].StageName != STAGE_AWAITING) {
      result.success = true;
      return result;
    }

  Opportunity opp = opps[0];
  opp.StageName = decision == 'Approved' ? STAGE_APPROVED : STAGE_REJECTED;
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

  private static String extractDecision(String body) {
    String text = body.toUpperCase();
    if (text.contains('APPROVED')) return 'Approved';
    if (text.contains('REJECTED')) return 'Rejected';
    return null;
  }
}