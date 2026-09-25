public with sharing class BatchJobManagerController {

    @AuraEnabled(cacheable=false)
    public static JobStatusWrapper getJobStatus(String batchClassName, String schedulerClassName, String jobName) {
        JobStatusWrapper status = new JobStatusWrapper();
        String targetJobName = String.isNotBlank(jobName) ? jobName : schedulerClassName;

        List<CronTrigger> cronList = [
            SELECT Id, State, NextFireTime, PreviousFireTime, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = :targetJobName
            LIMIT 1
        ];

        if (!cronList.isEmpty()) {
            CronTrigger ct = cronList[0];
            status.isScheduled = true;
            status.cronJobId = ct.Id;
            status.cronState = ct.State;
            status.nextFireTime = ct.NextFireTime;
            status.previousFireTime = ct.PreviousFireTime;
        } else {
            status.isScheduled = false;
        }

        List<AsyncApexJob> batchList = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedDate, CompletedDate
            FROM AsyncApexJob
            WHERE ApexClass.Name = :batchClassName
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!batchList.isEmpty()) {
            AsyncApexJob job = batchList[0];
            status.lastBatchStatus = job.Status;
            status.lastBatchCreatedDate = job.CreatedDate;
            status.lastBatchCompletedDate = job.CompletedDate;
            status.lastBatchErrors = job.NumberOfErrors;
            status.lastBatchItemsProcessed = job.JobItemsProcessed;
            status.lastBatchTotalItems = job.TotalJobItems;
        }

        return status;
    }

    @AuraEnabled
    public static String runBatchNow(String batchClassName, Integer scopeSize) {
        try {
            Type t = Type.forName(batchClassName);
            if (t == null) {
                throw new AuraHandledException('Class ' + batchClassName + ' not found.');
            }
            Object batchInstance = t.newInstance();
            if (!(batchInstance instanceof Database.Batchable<sObject>)) {
                throw new AuraHandledException('Class ' + batchClassName + ' dont realise Database.Batchable.');
            }
            Integer scope = (scopeSize != null && scopeSize > 0) ? scopeSize : 200;
            Id jobId = Database.executeBatch((Database.Batchable<sObject>)batchInstance, scope);
            return jobId;
        } catch (Exception e) {
            throw new AuraHandledException('Error when launching the batch: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String scheduleJob(String schedulerClassName, String jobName, String cronExpression) {
        try {
            Type t = Type.forName(schedulerClassName);
            if (t == null) {
                throw new AuraHandledException('Class ' + schedulerClassName + ' not found.');
            }
            Object schedInstance = t.newInstance();
            if (!(schedInstance instanceof Schedulable)) {
                throw new AuraHandledException('Class ' + schedulerClassName + ' does not implement a Scheduled one.');
            }

            String cron = String.isNotBlank(cronExpression) ? cronExpression : '0 0 0 * * ?';
            String targetJobName = String.isNotBlank(jobName) ? jobName : schedulerClassName;

            List<CronTrigger> existing = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :targetJobName];
            if (!existing.isEmpty()) {
                throw new AuraHandledException('Scheduler with the name "' + targetJobName + '" it already exists.');
            }

            Id jobId = System.schedule(targetJobName, cron, (Schedulable)schedInstance);
            return jobId;
        } catch (Exception e) {
            throw new AuraHandledException('Error when creating the chart: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void abortScheduledJob(String jobId) {
        try {
            if (String.isNotBlank(jobId)) {
                System.abortJob(jobId);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error when canceling the scheduler: ' + e.getMessage());
        }
    }

    public class JobStatusWrapper {
        @AuraEnabled public Boolean isScheduled;
        @AuraEnabled public String cronJobId;
        @AuraEnabled public String cronState;
        @AuraEnabled public Datetime nextFireTime;
        @AuraEnabled public Datetime previousFireTime;
        
        @AuraEnabled public String lastBatchStatus;
        @AuraEnabled public Datetime lastBatchCreatedDate;
        @AuraEnabled public Datetime lastBatchCompletedDate;
        @AuraEnabled public Integer lastBatchErrors;
        @AuraEnabled public Integer lastBatchItemsProcessed;
        @AuraEnabled public Integer lastBatchTotalItems;
    }
}