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
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c, Computed_Id_Account__c,
                   Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, 
                   Custom_Event_Page_URL__c, Event_Data_Sent_to_CSIS__c, CSIS_Transmission_Timestamp__c,
                   conference360__Organizer_Account__c, conference360__Organizer_Account__r.Acc_Number__c
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        if (events.isEmpty()) {
            return false;
        }
        
        updateComputedIdAccountField(events);
        
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
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c, Computed_Id_Account__c,
                   Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, 
                   Custom_Event_Page_URL__c, conference360__Organizer_Account__c,
                   conference360__Organizer_Account__r.Acc_Number__c
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        if (events.isEmpty()) {
            return false;
        }
        
        updateComputedIdAccountField(events);
        
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
                   conference360__Account__r.Computed_ID__c,conference360__Contact__r.Email, 
                   conference360__Contact__r.Phone, conference360__Contact__r.Fax,
                   conference360__Contact__r.MailingStreet, conference360__Contact__r.MailingCity,
                   conference360__Contact__r.MailingState, conference360__Contact__r.MailingPostalCode,
                   conference360__Contact__r.MailingCountry, conference360__Registration_Status__c,
                   conference360__Contact__r.AccountId, conference360__Event__r.externalId__c,
                   conference360__Event__c, conference360__Event__r.L3__c,
                   conference360__Event__r.Computed_Id_Account__c
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
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c, Computed_Id_Account__c,
                   Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, 
                   Custom_Event_Page_URL__c, conference360__Organizer_Account__c,
                   conference360__Organizer_Account__r.Acc_Number__c
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        if (events.isEmpty()) {
            return false;
        }
        
        updateComputedIdAccountField(events);
        
        return CSISIntegration.sendEventsWithJWT(events);
    }
    
    public static Id runBatchByRegAccountCode(String regAccountCode) {
        return CSISAttendeeBatch.runBatchForRegAccountCode(regAccountCode);
    }

    public static Boolean sendSpecificEventsAndAttendees(List<Id> eventIds, List<Id> attendeeIds) {
    if (eventIds == null || eventIds.isEmpty()) {
        return false;
    }
    
    List<conference360__Event__c> events = [
        SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
               conference360__Event_Start_Date__c, conference360__Event_End_Date__c, Computed_Id_Account__c,
               Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, 
               Custom_Event_Page_URL__c, Event_Data_Sent_to_CSIS__c, CSIS_Transmission_Timestamp__c,
               conference360__Organizer_Account__c, conference360__Organizer_Account__r.Acc_Number__c
        FROM conference360__Event__c 
        WHERE Id IN :eventIds
    ];
    
    if (events.isEmpty()) {
        return false;
    }
    
    updateComputedIdAccountField(events);
    
    // Convert attendeeIds list to a Set
    Set<Id> attendeeIdsSet = new Set<Id>();
    if (attendeeIds != null) {
        attendeeIdsSet.addAll(attendeeIds);
    }
    
    return CSISIntegration.sendEventsWithJWT(events, attendeeIdsSet);
}
    
    public static Id sendAllOrdersToCsis() {
        return CSISOrderBatch.runBatch();
    }
    
    public static Id sendNonIntegratedOrdersToCsis() {
        return CSISOrderBatch.runBatchForNonIntegrated();
    }
    
    public static Boolean sendSpecificOrder(Id orderId) {
        if (orderId == null) {
            return false;
        }
        
        bt_stripe__Sales_Document__c order = [
            SELECT externalId__c 
            FROM bt_stripe__Sales_Document__c 
            WHERE Id = :orderId 
            LIMIT 1
        ];
        
        if (order == null || String.isBlank(order.externalId__c)) {
            return false;
        }
        
        return CSISIntegration.sendOrderToCsis(order.externalId__c);
    }
    
    public static Boolean sendSpecificOrders(List<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return false;
        }
        
        List<bt_stripe__Sales_Document__c> orders = [
            SELECT externalId__c 
            FROM bt_stripe__Sales_Document__c 
            WHERE Id IN :orderIds
        ];
        
        if (orders.isEmpty()) {
            return false;
        }
        
        Boolean overallSuccess = true;
        
        for (bt_stripe__Sales_Document__c order : orders) {
            if (String.isNotBlank(order.externalId__c)) {
                Boolean success = CSISIntegration.sendOrderToCsis(order.externalId__c);
                if (!success) {
                    overallSuccess = false;
                }
            }
        }
        
        return overallSuccess;
    }
    
    private static void updateComputedIdAccountField(List<conference360__Event__c> events) {
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
                    SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                           conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                           Computed_Id_Account__c, Course_Offering__r.SectionNumber, 
                           conference360__Status__c, L3__c, Custom_Event_Page_URL__c,
                           conference360__Organizer_Account__r.Acc_Number__c
                    FROM conference360__Event__c 
                    WHERE Id IN :eventsToUpdate
                ]);
                
                for (Integer i = 0; i < events.size(); i++) {
                    if (refreshedEventsMap.containsKey(events[i].Id)) {
                        events[i].Computed_Id_Account__c = refreshedEventsMap.get(events[i].Id).Computed_Id_Account__c;
                    }
                }
                
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Error updating Computed_Id_Account__c: ' + ex.getMessage());
            }
        }
    }
}