public class AttendeeIntegrationHandler {
    private static Boolean isExecuting = false;
    
    public static void handleAfterInsert(List<conference360__Attendee__c> newAttendees) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            CSISIntegrationModels.setRegistrationStatus(null);
            CSISIntegrationManager.resetState();
            sendEventsToCsis(newAttendees);
        } finally {
            CSISIntegrationModels.setRegistrationStatus(null);
            CSISIntegrationManager.resetState();
            isExecuting = false;
        }
    }
    
    public static void handleAfterUpdate(List<conference360__Attendee__c> newAttendees, 
                                        Map<Id, conference360__Attendee__c> oldMap) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            List<conference360__Attendee__c> attendeesToSync = new List<conference360__Attendee__c>();
            List<conference360__Attendee__c> attendeesWithStatusChange = new List<conference360__Attendee__c>();
            List<conference360__Attendee__c> cancelledAttendees = new List<conference360__Attendee__c>();

            for (conference360__Attendee__c newAttendee : newAttendees) {
                conference360__Attendee__c oldAttendee = oldMap.get(newAttendee.Id);
                
                if (newAttendee.conference360__Registration_Status__c != oldAttendee.conference360__Registration_Status__c) {
                    attendeesWithStatusChange.add(newAttendee);
                    if ((//oldAttendee.conference360__Registration_Status__c != 'Cancelled' && 
                         oldAttendee.conference360__Registration_Status__c != 'Canceled') && 
                        (//newAttendee.conference360__Registration_Status__c == 'Cancelled' || 
                         newAttendee.conference360__Registration_Status__c == 'Canceled')) {
                        cancelledAttendees.add(newAttendee);
                    }
                }
                
                if (hasRelevantChanges(newAttendee, oldAttendee)) {
                    attendeesToSync.add(newAttendee);
                }
            }
            // if (!cancelledAttendees.isEmpty()) {
            //     updateLineItemsForCancelledAttendees(cancelledAttendees);
            // }
            if (!attendeesWithStatusChange.isEmpty()) {
                processAttendeeStatusChanges(attendeesWithStatusChange);
            }
            
            if (!attendeesToSync.isEmpty()) {
                sendEventsToCsis(attendeesToSync);
            }
        } finally {
            isExecuting = false;
        }
    }

    // private static void updateLineItemsForCancelledAttendees(List<conference360__Attendee__c> cancelledAttendees) {
    //     Set<Id> attendeeIds = new Set<Id>();
    //     Set<Id> orderIds = new Set<Id>();
        
    //     for (conference360__Attendee__c attendee : cancelledAttendees) {
    //         attendeeIds.add(attendee.Id);
    //         if (attendee.conference360__Sales_Document__c != null) {
    //             orderIds.add(attendee.conference360__Sales_Document__c);
    //         }
    //     }
    //     List<bt_stripe__Line_Item__c> lineItemsToUpdate = new List<bt_stripe__Line_Item__c>();
        
    //     for (bt_stripe__Line_Item__c lineItem : [
    //         SELECT Id, Line_Item_Status__c
    //         FROM bt_stripe__Line_Item__c
    //         WHERE conference360__Attendee__c IN :attendeeIds
    //     ]) {
    //         lineItem.Line_Item_Status__c = 'Canceled';
    //         lineItemsToUpdate.add(lineItem);
    //     }
        
    //     if (!orderIds.isEmpty()) {
    //         for (bt_stripe__Line_Item__c lineItem : [
    //             SELECT Id, Line_Item_Status__c
    //             FROM bt_stripe__Line_Item__c
    //             WHERE bt_stripe__Sales_Document__c IN :orderIds
    //         ]) {
    //             lineItem.Line_Item_Status__c = 'Canceled';
    //             lineItemsToUpdate.add(lineItem);
    //         }
    //     }
        
    //     if (!lineItemsToUpdate.isEmpty()) {
    //         try {
    //             update lineItemsToUpdate;
    //             System.debug('Updated ' + lineItemsToUpdate.size() + ' line items to Cancelled status');
    //         } catch (Exception ex) {
    //             System.debug(LoggingLevel.ERROR, 'Error updating line items: ' + ex.getMessage());
    //         }
    //     }
    // }
    
    private static void processAttendeeStatusChanges(List<conference360__Attendee__c> attendeesWithStatusChange) {
        List<Id> attendeeIds = new List<Id>();
        for (conference360__Attendee__c attendee : attendeesWithStatusChange) {
            attendeeIds.add(attendee.Id);
        }
        
        List<bt_stripe__Sales_Document__c> relatedOrders = new List<bt_stripe__Sales_Document__c>();
        
        try {
            relatedOrders = [
                SELECT Id, externalId__c
                FROM bt_stripe__Sales_Document__c
                WHERE Id IN (SELECT conference360__Sales_Document__c FROM conference360__Attendee__c WHERE Id IN :attendeeIds AND conference360__Sales_Document__c != null)
                AND externalId__c != null
            ];
        } catch (Exception e) {
            System.debug('Error finding sales documents via relationship: ' + e.getMessage());
        }
        
        if (relatedOrders.isEmpty()) {
            List<bt_stripe__Line_Item__c> lineItems = [
                SELECT Id, bt_stripe__Sales_Document__c, bt_stripe__Sales_Document__r.externalId__c
                FROM bt_stripe__Line_Item__c
                WHERE conference360__Attendee__c IN :attendeeIds
                AND bt_stripe__Sales_Document__r.externalId__c != null
            ];
            
            Set<Id> orderIds = new Set<Id>();
            for (bt_stripe__Line_Item__c item : lineItems) {
                orderIds.add(item.bt_stripe__Sales_Document__c);
            }
            
            if (!orderIds.isEmpty()) {
                relatedOrders = [
                    SELECT Id, externalId__c
                    FROM bt_stripe__Sales_Document__c
                    WHERE Id IN :orderIds
                    AND externalId__c != null
                ];
            }
        }
        
        if (!relatedOrders.isEmpty()) {
            List<bt_stripe__Sales_Document__c> ordersToUpdate = new List<bt_stripe__Sales_Document__c>();
            for (bt_stripe__Sales_Document__c order : relatedOrders) {
                ordersToUpdate.add(new bt_stripe__Sales_Document__c(
                    Id = order.Id,
                    Integration_Done__c = false
                ));
            }
            
            if (!ordersToUpdate.isEmpty()) {
                update ordersToUpdate;
                
                for (bt_stripe__Sales_Document__c order : relatedOrders) {
                    if (!Test.isRunningTest()) {
                        sendOrderWithStatusChangeFuture(order.externalId__c, attendeesWithStatusChange[0].Id);
                    } else {
                        processOrderWithStatusChange(order.externalId__c, attendeesWithStatusChange[0].Id);
                    }
                }
            }
        }
    }
    
    @future(callout=true)
    private static void sendOrderWithStatusChangeFuture(String orderExternalId, Id attendeeId) {
        processOrderWithStatusChange(orderExternalId, attendeeId);
    }
    
    private static void processOrderWithStatusChange(String orderExternalId, Id attendeeId) {
        try {
            conference360__Attendee__c attendee = [
                SELECT Id, conference360__Registration_Status__c
                FROM conference360__Attendee__c
                WHERE Id = :attendeeId
                LIMIT 1
            ];
            
            CSISIntegrationModels.setRegistrationStatus(attendee.conference360__Registration_Status__c);
            CSISIntegration.sendOrderToCsis(orderExternalId);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error processing order status change: ' + ex.getMessage());
        }
    }
    
    private static Boolean hasRelevantChanges(conference360__Attendee__c newAttendee, conference360__Attendee__c oldAttendee) {
        return newAttendee.conference360__First_Name2__c != oldAttendee.conference360__First_Name2__c ||
               newAttendee.conference360__Last_Name2__c != oldAttendee.conference360__Last_Name2__c ||
               newAttendee.conference360__Title__c != oldAttendee.conference360__Title__c ||
               newAttendee.conference360__Street__c != oldAttendee.conference360__Street__c ||
               newAttendee.conference360__City__c != oldAttendee.conference360__City__c ||
               newAttendee.conference360__State__c != oldAttendee.conference360__State__c ||
               newAttendee.conference360__Postal_Code__c != oldAttendee.conference360__Postal_Code__c ||
               newAttendee.conference360__Country__c != oldAttendee.conference360__Country__c ||
               newAttendee.conference360__Email__c != oldAttendee.conference360__Email__c ||
               newAttendee.conference360__Phone2__c != oldAttendee.conference360__Phone2__c ||
               newAttendee.Computed_Id__c != oldAttendee.Computed_Id__c ||
               newAttendee.conference360__Account__c != oldAttendee.conference360__Account__c ||
               newAttendee.conference360__Event__c != oldAttendee.conference360__Event__c ||
               newAttendee.conference360__Registration_Status__c != oldAttendee.conference360__Registration_Status__c ||
               newAttendee.conference360__Event_Item__c != oldAttendee.conference360__Event_Item__c ||
               newAttendee.conference360__Sales_Document__c != oldAttendee.conference360__Sales_Document__c;
    }
    
    private static void sendEventsToCsis(List<conference360__Attendee__c> attendees) {
        Set<Id> eventIds = new Set<Id>();
        Set<Id> attendeeIds = new Set<Id>();
        
        for (conference360__Attendee__c attendee : attendees) {
            if (attendee.conference360__Event__c != null) {
                eventIds.add(attendee.conference360__Event__c);
                attendeeIds.add(attendee.Id);
            }
        }
        
        if (eventIds.isEmpty()) {
            return;
        }
        
        if (!Test.isRunningTest()) {
            sendEventsFuture(new List<Id>(eventIds), new List<Id>(attendeeIds));
        } else {
            // CSISUtility.sendSpecificEvents(new List<Id>(eventIds));
            CSISUtility.sendSpecificEventsAndAttendees(new List<Id>(eventIds), new List<Id>(attendeeIds));
        }
    }
    
    @future(callout=true)
    private static void sendEventsFuture(List<Id> eventIds, List<Id> attendeeIds) {
        try {
            // CSISUtility.sendSpecificEvents(eventIds);
            CSISUtility.sendSpecificEventsAndAttendees(eventIds, attendeeIds);
        } catch (Exception ex) {
            System.debug('Error in future callout: ' + ex.getMessage());
        }
    }
}