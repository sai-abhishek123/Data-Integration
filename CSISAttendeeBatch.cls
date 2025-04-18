global class CSISAttendeeBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    private String query;
    
    global CSISAttendeeBatch() {
        this.query = 'SELECT Id, Computed_ID__c, conference360__Event__c, ' +
                    'integration_done__c, date_time_sent_to_csis__c ' +
                    'FROM conference360__Attendee__c';
    }
    
    global CSISAttendeeBatch(String query) {
        this.query = query;
    }
    
    global CSISAttendeeBatch(Boolean processOnlyNonIntegrated) {
        if (processOnlyNonIntegrated) {
            this.query = 'SELECT Id, Computed_ID__c, conference360__Event__c, ' +
                        'integration_done__c, date_time_sent_to_csis__c ' +
                        'FROM conference360__Attendee__c ' +
                        'WHERE integration_done__c = false OR integration_done__c = null';
        } else {
            this.query = 'SELECT Id, Computed_ID__c, conference360__Event__c, ' +
                        'integration_done__c, date_time_sent_to_csis__c ' +
                        'FROM conference360__Attendee__c';
        }
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bc, List<conference360__Attendee__c> scope) {
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
            Set<Id> eventIds = eventToAttendees.keySet();
            
            List<conference360__Event__c> events = [
                SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                       conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                       Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, 
                       conference360__Status__c, L3__c, conference360__Event_Page_URL__c
                FROM conference360__Event__c 
                WHERE Id IN :eventIds
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
        return Database.executeBatch(new CSISAttendeeBatch(), 100);
    }
    
    public static Id runBatchForNonIntegrated() {
        return Database.executeBatch(new CSISAttendeeBatch(true), 100);
    }
    
    public static Id runBatchForRegAccountCode(String regAccountCode) {
        String regQuery = 'SELECT Id, Computed_ID__c, conference360__Event__c, ' +
                        'conference360__Contact__r.externalId__c, conference360__Contact__r.AccountId, ' +
                        'Computed_ID__c, integration_done__c, date_time_sent_to_csis__c ' +
                        'FROM conference360__Attendee__c ' +
                        'WHERE conference360__Contact__r.externalId__c = \'' + regAccountCode + '\'';
        
        return Database.executeBatch(new CSISAttendeeBatch(regQuery), 100);
    }
}