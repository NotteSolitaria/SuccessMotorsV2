public with sharing class ContactBirthdayScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        ContactBirthdayBatch batch = new ContactBirthdayBatch();
        Database.executeBatch(batch, 200);
    }
}