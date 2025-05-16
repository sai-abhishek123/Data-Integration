// CSISAttendeeBatch.cls
global class CSISAttendeeBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    private String query;
    
    global CSISAttendeeBatch() {
        this.query = buildBaseQuery();
    }
    
    global CSISAttendeeBatch(String query) {
        this.query = query;
    }
    
    global CSISAttendeeBatch(Boolean processOnlyNonIntegrated) {
        if (processOnlyNonIntegrated) {
            this.query = buildBaseQuery() + ' WHERE integration_done__c = false OR integration_done__c = null';
        } else {
            this.query = buildBaseQuery();
        }
    }
    
    private String buildBaseQuery() {
        return 'SELECT Id, Computed_ID__c, conference360__Event__c, ' +
               'integration_done__c, date_time_sent_to_csis__c ' +
               'FROM conference360__Attendee__c';
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bc, List<conference360__Attendee__c> scope) {
        if (scope.isEmpty()) return;
        
        Map<Id, List<conference360__Attendee__c>> eventToAttendees = new Map<Id, List<conference360__Attendee__c>>();
        
        for (conference360__Attendee__c attendee : scope) {
            if (attendee.conference360__Event__c != null) {
                if (!eventToAttendees.containsKey(attendee.conference360__Event__c)) {
                    eventToAttendees.put(attendee.conference360__Event__c, new List<conference360__Attendee__c>());
                }
                eventToAttendees.get(attendee.conference360__Event__c).add(attendee);
            }
        }
        
        if (!eventToAttendees.isEmpty()) {
            processEventBatches(eventToAttendees.keySet());
        }
    }
    
    private void processEventBatches(Set<Id> eventIds) {
        // Process in smaller batches to avoid governor limits
        Integer batchSize = 5;
        List<Id> eventIdsList = new List<Id>(eventIds);
        
        for (Integer i = 0; i < eventIdsList.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, eventIdsList.size());
            Set<Id> batchEventIds = new Set<Id>();
            
            for (Integer j = i; j < endIndex; j++) {
                batchEventIds.add(eventIdsList[j]);
            }
            
            List<conference360__Event__c> events = [
                SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                       conference360__Event_Start_Date__c, conference360__Event_End_Date__c, Computed_Id_Account__c,
                       Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, 
                       conference360__Status__c, L3__c, Custom_Event_Page_URL__c
                FROM conference360__Event__c 
                WHERE Id IN :batchEventIds
            ];
            
            if (!events.isEmpty()) {
                CSISIntegration.sendEventsWithJWT(events);
            }
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('Finished sending attendees to CSIS');
    }
    
    public static Id runBatch() {
        return Database.executeBatch(new CSISAttendeeBatch(), 50);
    }
    
    public static Id runBatchForNonIntegrated() {
        return Database.executeBatch(new CSISAttendeeBatch(true), 50);
    }
    
    public static Id runBatchForRegAccountCode(String regAccountCode) {
        String regQuery = buildRegAccountCodeQuery(regAccountCode);
        return Database.executeBatch(new CSISAttendeeBatch(regQuery), 50);
    }
    
    private static String buildRegAccountCodeQuery(String regAccountCode) {
        return 'SELECT Id, Computed_ID__c, conference360__Event__c, ' +
               'conference360__Contact__r.externalId__c, conference360__Contact__r.AccountId, ' +
               'Computed_ID__c, integration_done__c, date_time_sent_to_csis__c ' +
               'FROM conference360__Attendee__c ' +
               'WHERE conference360__Contact__r.externalId__c = \'' + String.escapeSingleQuotes(regAccountCode) + '\'';
    }
}