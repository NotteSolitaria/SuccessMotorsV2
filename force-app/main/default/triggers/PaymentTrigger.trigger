trigger PaymentTrigger on Payment__c (after insert, after update, after delete, after undelete) {
    
    Set<String> oppNames = new Set<String>();
    
    if (Trigger.new != null) {
        for (Payment__c pay : Trigger.new) {
            if (String.isNotBlank(pay.OpportunityName__c)) {
                oppNames.add(pay.OpportunityName__c);
            }
        }
    }
    if (Trigger.old != null) {
        for (Payment__c pay : Trigger.old) {
            if (String.isNotBlank(pay.OpportunityName__c)) {
                oppNames.add(pay.OpportunityName__c);
            }
        }
    }
    
    if (oppNames.isEmpty()) return;

    Map<String, Opportunity> oppsByName = new Map<String, Opportunity>();
    for (Opportunity opp : [SELECT Id, Name, Amount, StageName, OwnerId FROM Opportunity WHERE Name IN :oppNames]) {
        oppsByName.put(opp.Name, opp);
    }
    
    if (oppsByName.isEmpty()) return;

    Map<String, Decimal> totalPaidByName = new Map<String, Decimal>();
    for (String oppName : oppNames) {
        totalPaidByName.put(oppName, 0);
    }

    for (AggregateResult ar : [
        SELECT OpportunityName__c, SUM(Amount__c) totalAmount 
        FROM Payment__c 
        WHERE OpportunityName__c IN :oppNames 
        GROUP BY OpportunityName__c
    ]) {
        totalPaidByName.put((String)ar.get('OpportunityName__c'), (Decimal)ar.get('totalAmount'));
    }

    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    List<Task> tasksToInsert = new List<Task>();

    Datetime reminderTime = Datetime.newInstance(Date.today().addDays(1), Time.newInstance(10, 0, 0, 0));
    
    for (String oppName : oppsByName.keySet()) {
        Opportunity opp = oppsByName.get(oppName);
        Decimal totalPaid = totalPaidByName.get(oppName);
        Decimal oppAmount = opp.Amount != null ? opp.Amount : 0;
        
        String newStage = opp.StageName;

        if (totalPaid > 0 && totalPaid < oppAmount) {
            newStage = 'Partially Paid';
        } else if (totalPaid >= oppAmount && oppAmount > 0) {
            newStage = 'Fully Paid';
        }

        if (opp.StageName != newStage) {
            opp.StageName = newStage;
            oppsToUpdate.add(opp);

            if (newStage == 'Fully Paid') {
                Task deliveryTask = new Task();
                deliveryTask.OwnerId = opp.OwnerId; 
                deliveryTask.Priority = 'High';
                deliveryTask.Status = 'Not Started';
                deliveryTask.Subject = 'Delivery of goods';
                deliveryTask.ReminderDateTime = reminderTime;
                deliveryTask.IsReminderSet = true;
                deliveryTask.WhatId = opp.Id;
                
                tasksToInsert.add(deliveryTask);
            }
        }
    }

    if (!oppsToUpdate.isEmpty()) {
        update oppsToUpdate;
    }
    
    if (!tasksToInsert.isEmpty()) {
        insert tasksToInsert;
    }
}