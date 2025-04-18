public class CSISUtility {
    
    public static Id sendAllEventsToCsis() {
        return CSISEventBatch.runBatch();
    }
    
    public static Id sendNonIntegratedEventsToCsis() {
        return Database.executeBatch(new CSISEventBatch(true), 100);
    }
    
    public static Id sendEventsByDateRange(Date startDate, Date endDate) {
        return CSISEventBatch.runBatchForDateRange(startDate, endDate);
    }
    
    public static Boolean sendSpecificEvents(List<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) {
            return false;
        }
        
        List<conference360__Event__c> events = [
            SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                   Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, 
                   conference360__Status__c, L3__c, conference360__Event_Page_URL__c,
                   integration_done__c, date_time_sent_to_csis__c
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        if (events.isEmpty()) {
            return false;
        }
        
        return CSISIntegration.sendEventsWithJWT(events);
    }
    
    public static Boolean sendSpecificAttendees(List<Id> attendeeIds) {
        if (attendeeIds == null || attendeeIds.isEmpty()) {
            return false;
        }
        
        List<conference360__Attendee__c> attendees = [
            SELECT Id, conference360__Event__c
            FROM conference360__Attendee__c
            WHERE Id IN :attendeeIds
        ];
        
        if (attendees.isEmpty()) {
            return false;
        }
        
        Set<Id> eventIds = new Set<Id>();
        for (conference360__Attendee__c attendee : attendees) {
            if (attendee.conference360__Event__c != null) {
                eventIds.add(attendee.conference360__Event__c);
            }
        }
        
        if (eventIds.isEmpty()) {
            return false;
        }
        
        List<conference360__Event__c> events = [
            SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                   Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, 
                   conference360__Status__c, L3__c, conference360__Event_Page_URL__c
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        if (events.isEmpty()) {
            return false;
        }
        
        return CSISIntegration.sendEventsWithJWT(events);
    }
    
    public static Boolean sendEventAttendees(Id eventId) {
        if (eventId == null) {
            return false;
        }
        
        return sendSpecificEvents(new List<Id>{eventId});
    }
    
    public static Id sendAllAttendeesToCsis() {
        return CSISAttendeeBatch.runBatch();
    }
    
    public static Id sendNonIntegratedAttendeesToCsis() {
        return CSISAttendeeBatch.runBatchForNonIntegrated();
    }
    
    public static Boolean sendAttendeesByRegAccountCode(String regAccountCode) {
        if (String.isBlank(regAccountCode)) {
            return false;
        }
        
        List<conference360__Attendee__c> attendees = [
            SELECT conference360__Contact__r.externalId__c, Computed_ID__c,
                   conference360__Contact__r.FirstName, conference360__Contact__r.LastName, 
                   conference360__Contact__r.Title, conference360__Account__r.Name,
                   conference360__Contact__r.Address__Street__s, conference360__Contact__r.Address__City__s, 
                   conference360__Contact__r.Address__StateCode__s, conference360__Contact__r.Address__PostalCode__s, 
                   conference360__Contact__r.Address__CountryCode__s, conference360__Contact__r.Email, 
                   conference360__Contact__r.Phone, conference360__Contact__r.Fax,
                   conference360__Contact__r.AccountId, conference360__Event__r.externalId__c,
                   conference360__Event__c, conference360__Event__r.L3__c
            FROM conference360__Attendee__c
            WHERE conference360__Contact__r.externalId__c = :regAccountCode
        ];
        
        if (attendees.isEmpty()) {
            return false;
        }
        
        Set<Id> eventIds = new Set<Id>();
        for (conference360__Attendee__c attendee : attendees) {
            if (attendee.conference360__Event__c != null) {
                eventIds.add(attendee.conference360__Event__c);
            }
        }
        
        if (eventIds.isEmpty()) {
            return false;
        }
        
        List<conference360__Event__c> events = [
            SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                   Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, 
                   conference360__Status__c, L3__c, conference360__Event_Page_URL__c
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        if (events.isEmpty()) {
            return false;
        }
        
        return CSISIntegration.sendEventsWithJWT(events);
    }
    
    public static Id runBatchByRegAccountCode(String regAccountCode) {
        return CSISAttendeeBatch.runBatchForRegAccountCode(regAccountCode);
    }
}