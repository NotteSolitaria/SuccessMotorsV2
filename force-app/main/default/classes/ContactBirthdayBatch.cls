public with sharing class ContactBirthdayBatch implements Database.Batchable<sObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integer currentDay = System.today().day();
        Integer currentMonth = System.today().month();
        
        return Database.getQueryLocator([
            SELECT Id, FirstName, LastName, Email, Birthdate 
            FROM Contact 
            WHERE Email != NULL 
              AND Birthdate != NULL 
              AND DAY_IN_MONTH(Birthdate) = :currentDay 
              AND CALENDAR_MONTH(Birthdate) = :currentMonth
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Contact> scope) {
        if (scope.isEmpty()) return;

        List<EmailTemplate> templates = [
            SELECT Id 
            FROM EmailTemplate 
            WHERE DeveloperName = 'Birthday_Congratulations' 
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'Email Template Birthday_Congratulations not found!');
            return;
        }

        Id templateId = templates[0].Id;
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        for (Contact c : scope) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(c.Id);
            email.setTemplateId(templateId);
            email.setSaveAsActivity(true);
            emailList.add(email);
        }

        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList, false);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('ContactBirthdayBatch successfully completed.');
    }
}