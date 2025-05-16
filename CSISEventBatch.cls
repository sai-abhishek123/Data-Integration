// CSISEventBatch.cls
global class CSISEventBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private Boolean processNonIntegratedOnly = false;
    private Date startDate;
    private Date endDate;
    private Boolean overallSuccess = true;
    private String query;
    
    public CSISEventBatch() {
        this.processNonIntegratedOnly = false;
        buildQuery();
    }
    
    public CSISEventBatch(Boolean processNonIntegratedOnly) {
        this.processNonIntegratedOnly = processNonIntegratedOnly;
        buildQuery();
    }
    
    public CSISEventBatch(Date startDate, Date endDate) {
        this.startDate = startDate;
        this.endDate = endDate;
        buildQuery();
    }
    
    private void buildQuery() {
        this.query = 'SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, ' 
                   + 'conference360__Event_Start_Date__c, conference360__Event_End_Date__c, Computed_Id_Account__c, '
                   + 'Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, '
                   + 'Custom_Event_Page_URL__c, conference360__Organizer_Account__c, '
                   + 'conference360__Organizer_Account__r.Acc_Number__c '
                   + 'FROM conference360__Event__c '
                   + 'WHERE externalId__c != null';
        
        if (processNonIntegratedOnly) {
            query += ' AND Event_Data_Sent_to_CSIS__c = false';
        }
        
        if (startDate != null && endDate != null) {
            query += ' AND conference360__Event_Start_Date__c >= :startDate AND conference360__Event_End_Date__c <= :endDate';
        }
    }
    
    public static Id runBatch() {
        CSISEventBatch batch = new CSISEventBatch();
        return Database.executeBatch(batch, 50);
    }
    
    public static Id runBatchForDateRange(Date startDate, Date endDate) {
        CSISEventBatch batch = new CSISEventBatch(startDate, endDate);
        return Database.executeBatch(batch, 50);
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<conference360__Event__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        
        // Process events in smaller chunks to avoid hitting limits
        Integer batchSize = 10;
        for (Integer i = 0; i < scope.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, scope.size());
            List<conference360__Event__c> batch = new List<conference360__Event__c>();
            
            for (Integer j = i; j < endIndex; j++) {
                batch.add(scope[j]);
            }
            
            try {
                // Update computed account IDs in batch
                updateComputedIdAccountFields(batch);
                
                // Send events to CSIS
                Boolean success = CSISIntegration.sendEventsWithJWT(batch);
                if (!success) {
                    overallSuccess = false;
                }
            } catch (Exception ex) {
                overallSuccess = false;
                System.debug('Exception processing events batch: ' + ex.getMessage());
            }
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :BC.getJobId()
        ];
        
        System.debug('CSIS Event Batch job completed - Status: ' + job.Status 
                   + ', Items Processed: ' + job.JobItemsProcessed
                   + ', Total Items: ' + job.TotalJobItems
                   + ', Errors: ' + job.NumberOfErrors
                   + ', Overall Success: ' + overallSuccess);
    }
    
    private void updateComputedIdAccountFields(List<conference360__Event__c> events) {
        Set<Id> accountIds = new Set<Id>();
        Map<Id, conference360__Event__c> eventsToUpdateMap = new Map<Id, conference360__Event__c>();
        
        for (conference360__Event__c event : events) {
            if (event.conference360__Organizer_Account__c != null && 
                (event.Computed_Id_Account__c == null || String.isBlank(event.Computed_Id_Account__c))) {
                accountIds.add(event.conference360__Organizer_Account__c);
                eventsToUpdateMap.put(event.Id, event);
            }
        }
        
        if (accountIds.isEmpty()) {
            return;
        }
        
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Computed_ID__c 
            FROM Account 
            WHERE Id IN :accountIds
        ]);
        
        List<conference360__Event__c> eventsToUpdate = new List<conference360__Event__c>();
        for (conference360__Event__c event : eventsToUpdateMap.values()) {
            if (accountMap.containsKey(event.conference360__Organizer_Account__c) &&
                accountMap.get(event.conference360__Organizer_Account__c).Computed_ID__c != null) {
                
                conference360__Event__c updatedEvent = new conference360__Event__c(
                    Id = event.Id,
                    Computed_Id_Account__c = accountMap.get(event.conference360__Organizer_Account__c).Computed_ID__c
                );
                eventsToUpdate.add(updatedEvent);
            }
        }
        
        if (!eventsToUpdate.isEmpty()) {
            try {
                update eventsToUpdate;
                
                Map<Id, conference360__Event__c> refreshedEventsMap = new Map<Id, conference360__Event__c>([
                    SELECT Id, Computed_Id_Account__c
                    FROM conference360__Event__c 
                    WHERE Id IN :eventsToUpdate
                ]);
                
                for (conference360__Event__c event : events) {
                    if (refreshedEventsMap.containsKey(event.Id)) {
                        event.Computed_Id_Account__c = refreshedEventsMap.get(event.Id).Computed_Id_Account__c;
                    }
                }
                
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Error updating Computed_Id_Account__c: ' + ex.getMessage());
            }
        }
    }
 }