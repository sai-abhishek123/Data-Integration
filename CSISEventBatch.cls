global class CSISEventBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    private String query;
    
    global CSISEventBatch() {
        this.query = 'SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, ' +
                    'conference360__Event_Start_Date__c, conference360__Event_End_Date__c, ' +
                    'Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, ' +
                    'conference360__Status__c, L3__c, conference360__Event_Page_URL__c, ' +
                    'integration_done__c, date_time_sent_to_csis__c ' +
                    'FROM conference360__Event__c';
    }
    
    global CSISEventBatch(String query) {
        this.query = query;
    }
    
    global CSISEventBatch(Boolean processOnlyNonIntegrated) {
        if (processOnlyNonIntegrated) {
            this.query = 'SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, ' +
                        'conference360__Event_Start_Date__c, conference360__Event_End_Date__c, ' +
                        'Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, ' +
                        'conference360__Status__c, L3__c, conference360__Event_Page_URL__c, ' +
                        'integration_done__c, date_time_sent_to_csis__c ' +
                        'FROM conference360__Event__c ' +
                        'WHERE integration_done__c = false OR integration_done__c = null';
        } else {
            this.query = 'SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, ' +
                        'conference360__Event_Start_Date__c, conference360__Event_End_Date__c, ' +
                        'Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, ' +
                        'conference360__Status__c, L3__c, conference360__Event_Page_URL__c, ' +
                        'integration_done__c, date_time_sent_to_csis__c ' +
                        'FROM conference360__Event__c';
        }
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bc, List<conference360__Event__c> scope) {
        Integer batchSize = 50;
        List<conference360__Event__c> currentBatch = new List<conference360__Event__c>();
        
        for (Integer i = 0; i < scope.size(); i++) {
            currentBatch.add(scope[i]);
            
            if (currentBatch.size() == batchSize || i == scope.size() - 1) {
                if (!currentBatch.isEmpty()) {
                    CSISIntegration.sendEventsWithJWT(currentBatch);
                    
                    currentBatch.clear();
                }
            }
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('Finished sending events to CSIS');
    }
    
    public static Id runBatch() {
        return Database.executeBatch(new CSISEventBatch(), 100);
    }
    
    public static Id runBatchForDateRange(Date startDate, Date endDate) {
        String dateQuery = 'SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, ' +
                          'conference360__Event_Start_Date__c, conference360__Event_End_Date__c, ' +
                          'Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, ' +
                          'conference360__Status__c, L3__c, conference360__Event_Page_URL__c, ' +
                          'integration_done__c, date_time_sent_to_csis__c ' +
                          'FROM conference360__Event__c ' +
                          'WHERE conference360__Event_Start_Date__c >= :startDate ' +
                          'AND conference360__Event_Start_Date__c <= :endDate';
        
        return Database.executeBatch(new CSISEventBatch(dateQuery), 100);
    }
}