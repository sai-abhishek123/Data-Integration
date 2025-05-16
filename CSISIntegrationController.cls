public class CSISIntegrationController {
    
    @AuraEnabled
    public static String sendEventToCsis(Id eventId) {
        try {
            if (eventId == null) {
                return 'Error: Event ID is required';
            }
            
            List<conference360__Event__c> events = [
                SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                       conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                       Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, EventID__c,
                       Custom_Event_Page_URL__c, conference360__Organizer_Account__r.Computed_ID__c
                FROM conference360__Event__c 
                WHERE Id = :eventId
                LIMIT 1
            ];
            
            if (events.isEmpty()) {
                return 'Error: Event not found';
            }
            
            Boolean success = CSISIntegration.sendEventsWithJWT(events);
            
            if (success) {
                return 'Success: Event sent to CSIS';
            } else {
                return 'Error: Failed to send event to CSIS. Check debug logs for details.';
            }
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String sendOrderToCsis(Id orderId) {
        try {
            if (orderId == null) {
                return 'Error: Order ID is required';
            }
            
            List<bt_stripe__Sales_Document__c> orders = [
                SELECT Id, externalId__c 
                FROM bt_stripe__Sales_Document__c 
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            if (orders.isEmpty()) {
                return 'Error: Order not found';
            }
            
            if (String.isBlank(orders[0].externalId__c)) {
                return 'Error: Order does not have an external ID';
            }
            
            Boolean success = CSISIntegration.sendOrderToCsis(orders[0].externalId__c);
            
            if (success) {
                return 'Success: Order sent to CSIS';
            } else {
                return 'Error: Failed to send order to CSIS. Check debug logs for details.';
            }
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String sendAttendeeToCsis(Id attendeeId) {
        try {
            if (attendeeId == null) {
                return 'Error: Attendee ID is required';
            }
            
            List<conference360__Attendee__c> attendees = [
                SELECT Id, conference360__Event__c
                FROM conference360__Attendee__c
                WHERE Id = :attendeeId
                LIMIT 1
            ];
            
            if (attendees.isEmpty()) {
                return 'Error: Attendee not found';
            }
            
            if (attendees[0].conference360__Event__c == null) {
                return 'Error: Attendee is not associated with an event';
            }
            
            List<conference360__Event__c> events = [
                SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                       conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                       Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, 
                       Custom_Event_Page_URL__c, conference360__Organizer_Account__r.Computed_ID__c
                FROM conference360__Event__c 
                WHERE Id = :attendees[0].conference360__Event__c
                LIMIT 1
            ];
            
            if (events.isEmpty()) {
                return 'Error: Event not found for attendee';
            }
            
            Boolean success = CSISIntegration.sendEventsWithJWT(events);
            
            if (success) {
                return 'Success: Attendee sent to CSIS via event';
            } else {
                return 'Error: Failed to send attendee to CSIS. Check debug logs for details.';
            }
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String runFullIntegration() {
        try {
            Id batchJobId = Database.executeBatch(new CSISEventBatch(), 100);
            Database.executeBatch(new CSISOrderBatch(), 100);
            Database.executeBatch(new CSISAttendeeBatch(), 100);
            
            return 'Success: Integration jobs started. Batch job ID: ' + batchJobId;
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String runPendingIntegration() {
        try {
            Id batchJobId = Database.executeBatch(new CSISEventBatch(true), 100);
            Database.executeBatch(new CSISOrderBatch(true), 100);
            Database.executeBatch(new CSISAttendeeBatch(true), 100);
            
            return 'Success: Pending integration jobs started. Batch job ID: ' + batchJobId;
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
}