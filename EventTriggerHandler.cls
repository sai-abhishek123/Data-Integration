// EventTriggerHandler.cls
public class EventTriggerHandler {
    
    private static Set<Id> processedEventIds = new Set<Id>();
    
    public static void handleAfterInsert(List<conference360__Event__c> newEvents) {
        List<conference360__Event__c> approvedEvents = new List<conference360__Event__c>();
        
        for (conference360__Event__c event : newEvents) {
            if (event.Approved_to_Send_to_CSIS__c == true) {
                approvedEvents.add(event);
            }
        }
        
        List<conference360__Event__c> filteredEvents = filterAlreadyProcessedEvents(approvedEvents);
        
        if (!filteredEvents.isEmpty()) {
            if (!Test.isRunningTest()) {
                sendEventsWithDelay(JSON.serialize(filteredEvents));
            } else {
                CSISIntegration.sendEventsWithJWT(filteredEvents); 
            }
        }
    }
    
    public static void handleAfterUpdate(List<conference360__Event__c> newEvents, 
                                       Map<Id, conference360__Event__c> oldMap) {
        List<conference360__Event__c> eventsToSync = new List<conference360__Event__c>();
        
        for (conference360__Event__c newEvent : newEvents) {
            if (processedEventIds.contains(newEvent.Id)) {
                continue;
            }
            
            conference360__Event__c oldEvent = oldMap.get(newEvent.Id);
            
            if (oldEvent.Approved_to_Send_to_CSIS__c == false && newEvent.Approved_to_Send_to_CSIS__c == true) {
                eventsToSync.add(newEvent);
            }
        }
        
        if (!eventsToSync.isEmpty()) {
            if (!Test.isRunningTest()) {
                sendEventsWithDelay(JSON.serialize(eventsToSync));
            } else {
                CSISIntegration.sendEventsWithJWT(eventsToSync);
            }
        }
    }
    
    private static List<conference360__Event__c> filterAlreadyProcessedEvents(List<conference360__Event__c> events) {
        List<conference360__Event__c> filteredEvents = new List<conference360__Event__c>();
        
        for (conference360__Event__c event : events) {
            if (!processedEventIds.contains(event.Id)) {
                filteredEvents.add(event);
                processedEventIds.add(event.Id);
            }
        }
        
        return filteredEvents;
    }
    
    @future(callout=true)
    private static void sendEventsWithDelay(String serializedEvents) {
        try {
            List<conference360__Event__c> deserializedEvents = 
                (List<conference360__Event__c>)JSON.deserialize(serializedEvents, 
                                                             List<conference360__Event__c>.class);
            
            Set<Id> eventIds = new Set<Id>();
            for(conference360__Event__c evt : deserializedEvents) {
                eventIds.add(evt.Id);
            }
            
            List<conference360__Event__c> refreshedEvents = [
                SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                       conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                       Computed_Id_Account__c, Course_Offering__r.SectionNumber, 
                       conference360__Status__c, L3__c, Custom_Event_Page_URL__c,
                       conference360__Organizer_Account__c, conference360__Organizer_Account__r.Name,
                       EventID__c, Event_Data_Sent_to_CSIS__c, conference360__Organizer_Account__r.Acc_Number__c
                FROM conference360__Event__c 
                WHERE Id IN :eventIds
            ];
            
            // Update Computed_Id_Account__c if needed
            Set<Id> accountIds = new Set<Id>();
            Map<Id, conference360__Event__c> eventsToUpdateMap = new Map<Id, conference360__Event__c>();
            
            for (conference360__Event__c event : refreshedEvents) {
                if (event.conference360__Organizer_Account__c != null && 
                    (event.Computed_Id_Account__c == null || String.isBlank(event.Computed_Id_Account__c))) {
                    accountIds.add(event.conference360__Organizer_Account__c);
                    eventsToUpdateMap.put(event.Id, event);
                }
            }
            
            if (!accountIds.isEmpty()) {
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
                    update eventsToUpdate;
                    
                    refreshedEvents = [
                        SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                               conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                               Computed_Id_Account__c, Course_Offering__r.SectionNumber, 
                               conference360__Status__c, L3__c, Custom_Event_Page_URL__c,
                               conference360__Organizer_Account__c, conference360__Organizer_Account__r.Name,
                               EventID__c, Event_Data_Sent_to_CSIS__c, conference360__Organizer_Account__r.Acc_Number__c
                        FROM conference360__Event__c 
                        WHERE Id IN :eventIds
                    ];
                }
            }
            
            CSISIntegration.sendEventsWithJWT(refreshedEvents);
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in future callout: ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + ex.getStackTraceString());
        }
    }
}