public class AttendeeIntegrationHandler {
    
    public static void handleAfterInsert(List<conference360__Attendee__c> newAttendees) {
        processAttendees(newAttendees);
    }
    
    public static void handleAfterUpdate(List<conference360__Attendee__c> newAttendees, 
                                       Map<Id, conference360__Attendee__c> oldMap) {
        List<conference360__Attendee__c> attendeesToSync = new List<conference360__Attendee__c>();
        
        for (conference360__Attendee__c newAttendee : newAttendees) {
            conference360__Attendee__c oldAttendee = oldMap.get(newAttendee.Id);
            
            if (hasRelevantChanges(newAttendee, oldAttendee)) {
                attendeesToSync.add(newAttendee);
            }
        }
        
        if (!attendeesToSync.isEmpty()) {
            processAttendees(attendeesToSync);
        }
    }
    
    private static Boolean hasRelevantChanges(conference360__Attendee__c newAttendee, 
                                            conference360__Attendee__c oldAttendee) {
        return newAttendee.conference360__Contact__c != oldAttendee.conference360__Contact__c ||
               newAttendee.conference360__Account__c != oldAttendee.conference360__Account__c ||
               newAttendee.conference360__Event__c != oldAttendee.conference360__Event__c ||
               newAttendee.Computed_ID__c != oldAttendee.Computed_ID__c;
    }
    
    private static void processAttendees(List<conference360__Attendee__c> attendees) {
        Set<Id> eventIds = new Set<Id>();
        for (conference360__Attendee__c attendee : attendees) {
            if (attendee.conference360__Event__c != null) {
                eventIds.add(attendee.conference360__Event__c);
            }
        }
        
        if (!eventIds.isEmpty()) {
            List<conference360__Event__c> events = [
                SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c,
                       conference360__Event_Start_Date__c, conference360__Event_End_Date__c,
                       Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c,
                       conference360__Status__c, L3__c, conference360__Event_Page_URL__c
                FROM conference360__Event__c
                WHERE Id IN :eventIds
            ];
            
            if (!events.isEmpty() && !Test.isRunningTest()) {
                sendEventsFuture(JSON.serialize(events));
            }
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