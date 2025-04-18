public class EventTriggerHandler {
    
    public static void handleAfterInsert(List<conference360__Event__c> newEvents) {
        sendEventsToCsis(newEvents);
    }
    
    public static void handleAfterUpdate(List<conference360__Event__c> newEvents, 
                                       Map<Id, conference360__Event__c> oldMap) {
        List<conference360__Event__c> eventsToSync = new List<conference360__Event__c>();
        
        for (conference360__Event__c newEvent : newEvents) {
            conference360__Event__c oldEvent = oldMap.get(newEvent.Id);
            
            if (hasRelevantChanges(newEvent, oldEvent)) {
                eventsToSync.add(newEvent);
            }
        }
        
        if (!eventsToSync.isEmpty()) {
            sendEventsToCsis(eventsToSync);
        }
    }
    
    private static Boolean hasRelevantChanges(conference360__Event__c newEvent, 
                                            conference360__Event__c oldEvent) {
        return newEvent.Name != oldEvent.Name || newEvent.conference360__Organizer_Account__c != oldEvent.conference360__Organizer_Account__c ||
               newEvent.externalId__c != oldEvent.externalId__c || newEvent.EventID__c != oldEvent.EventID__c ||
               newEvent.conference360__Event_Start_Date__c != oldEvent.conference360__Event_Start_Date__c ||
               newEvent.conference360__Event_End_Date__c != oldEvent.conference360__Event_End_Date__c ||
               newEvent.conference360__Status__c != oldEvent.conference360__Status__c ||
               newEvent.L3__c != oldEvent.L3__c ||
               newEvent.conference360__Event_Page_URL__c != oldEvent.conference360__Event_Page_URL__c ||
               false;
    }
    
    private static void sendEventsToCsis(List<conference360__Event__c> events) {
        if (!Test.isRunningTest()) {
            sendEventsFuture(JSON.serialize(events));
        } else {
            CSISIntegration.sendEventsWithJWT(events);
        }
    }
    
    @future(callout=true)
    private static void sendEventsFuture(String serializedEvents) {
        try {
            List<conference360__Event__c> events = 
                (List<conference360__Event__c>)JSON.deserialize(serializedEvents, 
                                                             List<conference360__Event__c>.class);
            CSISIntegration.sendEventsWithJWT(events);
        } catch (Exception ex) {
            System.debug('Error in future callout: ' + ex.getMessage());
        }
    }
}