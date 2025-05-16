public class CSISIntegration {

    public static Boolean sendEventsWithJWT(List<conference360__Event__c> events, Set<Id> specificAttendeeIds) {
        if (events == null || events.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'CSIS Integration: Invalid input - events empty');
            return false;
        }
        CSISIntegrationModels.setRegistrationStatus(null);
        Set<Id> eventIds = new Set<Id>();
        for (conference360__Event__c evt : events) {
            eventIds.add(evt.Id);
        }
        
        List<conference360__Event__c> fullEvents = [
            SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, Department__r.Computed_ID__c,
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c,
                   Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, EventID__c,
                   Custom_Event_Page_URL__c, conference360__Organizer_Account__c,
                   conference360__Organizer_Account__r.Computed_ID__c,
                   conference360__Organizer_Account__r.Name
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        // Map<Id, List<conference360__Attendee__c>> eventToAttendeesMap = new Map<Id, List<conference360__Attendee__c>>();
        // for (conference360__Attendee__c attendee : [SELECT Id, Computed_ID__c, conference360__Event__c,
        //            conference360__First_Name2__c, conference360__Last_Name2__c, 
        //            conference360__Title__c, conference360__Street__c, conference360__City__c,
        //            conference360__State__c, conference360__Postal_Code__c, conference360__Country__c,
        //            conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c,
        //            conference360__Contact__r.externalId__c, conference360__Contact__r.Fax,
        //            conference360__Account__r.Name, conference360__Account__r.Computed_ID__c,
        //            conference360__Event__r.EventID__c, conference360__Event__r.externalId__c,
        //            conference360__Event__r.L3__c, conference360__Event_Item__r.conference360__Product__r.ProductCode,
        //            conference360__Event_Item__r.conference360__Product__r.Product_Base__c
        //     FROM conference360__Attendee__c
        //     WHERE conference360__Event__c IN :eventIds
        // ]) {
        //     if (!eventToAttendeesMap.containsKey(attendee.conference360__Event__c)) {
        //         eventToAttendeesMap.put(attendee.conference360__Event__c, new List<conference360__Attendee__c>());
        //     }
        //     eventToAttendeesMap.get(attendee.conference360__Event__c).add(attendee);
        // }

        Map<Id, List<conference360__Attendee__c>> eventToAttendeesMap = new Map<Id, List<conference360__Attendee__c>>();

// Create a dynamic query string
String attendeeQuery = 'SELECT Id, Computed_ID__c, conference360__Event__c, ' +
                 'conference360__First_Name2__c, conference360__Last_Name2__c, ' +
                 'conference360__Title__c, conference360__Street__c, conference360__City__c, ' +
                 'conference360__State__c, conference360__Postal_Code__c, conference360__Country__c, ' +
                 'conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c, ' +
                 'conference360__Contact__r.externalId__c, conference360__Contact__r.Fax, ' +
                 'conference360__Account__r.Name, conference360__Account__r.Computed_ID__c, ' +
                 'conference360__Event__r.EventID__c, conference360__Event__r.externalId__c, ' +
                 'conference360__Event__r.L3__c, conference360__Event_Item__r.conference360__Product__r.ProductCode, ' +
                 'conference360__Event_Item__r.conference360__Product__r.Product_Base__c ' +
                 'FROM conference360__Attendee__c ' +
                 'WHERE conference360__Event__c IN :eventIds'; 

if (specificAttendeeIds != null && !specificAttendeeIds.isEmpty()) {
    attendeeQuery += ' AND Id IN :specificAttendeeIds';
}

for (conference360__Attendee__c attendee : Database.query(attendeeQuery)) {
    if (!eventToAttendeesMap.containsKey(attendee.conference360__Event__c)) {
        eventToAttendeesMap.put(attendee.conference360__Event__c, new List<conference360__Attendee__c>());
    }
    eventToAttendeesMap.get(attendee.conference360__Event__c).add(attendee);
}
        
        Boolean overallSuccess = true;
        List<conference360__Event__c> eventsToUpdate = new List<conference360__Event__c>();
        List<conference360__Attendee__c> attendeesToUpdate = new List<conference360__Attendee__c>();
        Datetime now = Datetime.now();
        
        for (conference360__Event__c event : fullEvents) {
            CSISIntegrationModels.EventDataModel eventModel = new CSISIntegrationModels.EventDataModel(event);
            List<CSISIntegrationModels.CsisRegistrant> registrantModels = new List<CSISIntegrationModels.CsisRegistrant>();
            
            List<conference360__Attendee__c> attendees = eventToAttendeesMap.containsKey(event.Id) 
                ? eventToAttendeesMap.get(event.Id) 
                : new List<conference360__Attendee__c>();
            
            for (conference360__Attendee__c attendee : attendees) {
                CSISIntegrationModels.CsisRegistrant registrantModel = new CSISIntegrationModels.CsisRegistrant(attendee);
                registrantModels.add(registrantModel);
                
                attendeesToUpdate.add(new conference360__Attendee__c(
                    Id = attendee.Id,
                    integration_done__c = true,
                    date_time_sent_to_csis__c = now
                ));
            }
            
            CSISIntegrationModels.CSISPayload payload = new CSISIntegrationModels.CSISPayload();
            payload.data.eventData = eventModel;
            payload.data.registrants = registrantModels.isEmpty() ? null : registrantModels;
            
            String jsonBody = JSON.serialize(payload);
            System.debug('CSIS JSON Payload: ' + jsonBody);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:CSIS_Endpoint');
            req.setMethod('POST');
            req.setBody(jsonBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                System.debug('CSIS callout response for event ' + event.Id + ': ' + res.getBody());
                
                boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
                
                if (success) {
                    eventsToUpdate.add(new conference360__Event__c(
                        Id = event.Id,
                        Event_Data_Sent_to_CSIS__c = true,
                        CSIS_Transmission_Timestamp__c = now
                    ));
                } else {
                    System.debug(LoggingLevel.ERROR, 'Failed to send event to CSIS: ' + res.getStatusCode() + ': ' + res.getBody());
                    overallSuccess = false;
                }
            } catch(Exception ex) {
                System.debug('CSIS callout exception for event ' + event.Id + ': ' + ex.getMessage());
                overallSuccess = false;
            }
        }
        
        if (!eventsToUpdate.isEmpty()) {
            update eventsToUpdate;
        }
        
        if (!attendeesToUpdate.isEmpty()) {
            update attendeesToUpdate;
        }
        
        return overallSuccess;
    }
public static Boolean sendEventsWithJWT(List<conference360__Event__c> events) {
    // This preserves backward compatibility
    return sendEventsWithJWT(events, null);
}
    public static Boolean sendOrderToCsis(String orderExternalId) {
        System.debug('Order External ID: ' + orderExternalId);
        if (String.isBlank(orderExternalId)) {
            return false;
        }
        CSISIntegrationModels.setRegistrationStatus(null);
        try {
            bt_stripe__Sales_Document__c orderDoc = [
                SELECT Id, externalId__c, bt_stripe__Bill_To__c, Name,
                       bt_stripe__Bill_To__r.externalId__c, bt_stripe__Payment_Status__c, 
                       conference360__Event__c, conference360__Event__r.externalId__c, conference360__Event__r.EventID__c,
                       conference360__Event__r.conference360__Organizer_Account__r.Computed_ID__c,
                       bt_stripe__Total_Amount__c, bt_stripe__Balance_Paid_Amount__c, createdDate, 
                       bt_stripe__Balance_Due_Amount__c, LastModifiedDate, bt_stripe__Tax_Amount__c, 
                       conference360__Event__r.L3__c, bt_stripe__Bill_To__r.Computed_ID__c, bt_Stripe__Status__c
                FROM bt_stripe__Sales_Document__c 
                WHERE externalId__c = :orderExternalId
                LIMIT 1
            ];
            
            conference360__Attendee__c relatedAttendee;
            
            try {
                relatedAttendee = [
                SELECT Id, Computed_ID__c, conference360__Event__c, conference360__Sales_Document__c,
               conference360__First_Name2__c, conference360__Last_Name2__c, 
               conference360__Title__c, conference360__Street__c, conference360__City__c,
               conference360__State__c, conference360__Postal_Code__c, conference360__Country__c,
               conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c,
               conference360__Contact__r.externalId__c, conference360__Contact__r.Fax,
               conference360__Account__r.Name, conference360__Account__r.Computed_ID__c,
               conference360__Event__r.externalId__c, conference360__Event__r.L3__c, conference360__Event__r.EventID__c,
               conference360__Event_Item__r.conference360__Product__r.ProductCode,
               conference360__Event_Item__r.conference360__Product__r.Product_Base__c
        FROM conference360__Attendee__c 
        WHERE conference360__Sales_Document__c = :orderDoc.Id 
        LIMIT 1
    ];
            } catch (Exception e) {
                relatedAttendee = null;
                System.debug('No related attendee found via direct relationship: ' + e.getMessage());
            }

            List<bt_stripe__Line_Item__c> lineItems = [
                SELECT Id, bt_stripe__Sales_Document__c, bt_stripe__Sales_Document__r.externalId__c, bt_stripe__Sales_Document__r.Name,
                        bt_stripe__Sort_Order__c, conference360__Attendee__c, conference360__Attendee__r.Computed_ID__c,
                        conference360__Attendee__r.conference360__Account__r.Computed_ID__c,
                        conference360__Attendee__r.conference360__Event_Item__r.conference360__Product__r.ProductCode,
                        conference360__Event_Item__r.conference360__Product__r.Product_Base__c,
                        conference360__Event_Item__r.conference360__Product__r.ProductCode,
                        bt_stripe__Description__c, bt_stripe__Quantity__c, bt_stripe__List_Price__c, 
                        bt_stripe__Tax_Amount__c, createdDate, LastModifiedDate, bt_stripe__Item_Name__c, Line_Item_Status__c,
                        bt_stripe__Product__c, bt_stripe__Product__r.ProductCode, bt_stripe__Product__r.Product_Base__c
                FROM bt_stripe__Line_Item__c 
                WHERE bt_stripe__Sales_Document__r.externalId__c = :orderExternalId
            ];
            
            Set<Id> attendeeIds = new Set<Id>();
            if (relatedAttendee == null) {
                for (bt_stripe__Line_Item__c item : lineItems) {
                    if (item.conference360__Attendee__c != null) {
                        attendeeIds.add(item.conference360__Attendee__c);
                    }
                }
            }
            
            List<conference360__Attendee__c> attendees = new List<conference360__Attendee__c>();
            if (!attendeeIds.isEmpty()) {
                attendees = [
                    SELECT Id, Computed_ID__c, conference360__Event__c, conference360__Sales_Document__c,
                           conference360__First_Name2__c, conference360__Last_Name2__c, 
                           conference360__Title__c, conference360__Street__c, conference360__City__c,
                           conference360__State__c, conference360__Postal_Code__c, conference360__Country__c,
                           conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c,
                           conference360__Contact__r.externalId__c, conference360__Contact__r.Fax,
                           conference360__Account__r.Name, conference360__Account__r.Computed_ID__c,
                           conference360__Event__r.externalId__c, conference360__Event__r.L3__c, conference360__Event__r.EventID__c,
                           conference360__Event_Item__r.conference360__Product__r.ProductCode,
                           conference360__Event_Item__r.conference360__Product__r.Product_Base__c
                    FROM conference360__Attendee__c
                    WHERE Id IN :attendeeIds
                ];
            } else if (relatedAttendee == null && orderDoc.conference360__Event__c != null && orderDoc.bt_stripe__Bill_To__c != null) {
                attendees = [
                    SELECT Id, Computed_Id__c, conference360__Event__c, conference360__Sales_Document__c,
                           conference360__First_Name2__c, conference360__Last_Name2__c, 
                           conference360__Title__c, conference360__Street__c, conference360__City__c,
                           conference360__State__c, conference360__Postal_Code__c, conference360__Country__c,
                           conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c,
                           conference360__Contact__r.externalId__c, conference360__Contact__r.Fax,
                           conference360__Account__r.Name, conference360__Account__r.Computed_ID__c,
                           conference360__Event__r.externalId__c, conference360__Event__r.L3__c, conference360__Event__r.EventID__c,
                           conference360__Event_Item__r.conference360__Product__r.ProductCode,
                           conference360__Event_Item__r.conference360__Product__r.Product_Base__c
                    FROM conference360__Attendee__c
                    WHERE conference360__Event__c = :orderDoc.conference360__Event__c 
                    AND conference360__Contact__r.AccountId = :orderDoc.bt_stripe__Bill_To__c
                    LIMIT 5
                ];
            }
            
            return sendOrderAndRegistrantsToCSIS(orderDoc, lineItems, attendees, relatedAttendee);
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'CSIS Order Integration error: ' + ex.getMessage());
            return false;
        }
    }
    
    private static Boolean sendOrderAndRegistrantsToCSIS(bt_stripe__Sales_Document__c orderDoc, List<bt_stripe__Line_Item__c> lineItems, List<conference360__Attendee__c> attendees, conference360__Attendee__c attendeeWithStatus) {
        CSISIntegrationModels.setRegistrationStatus(null);
        List<CSISIntegrationModels.CsisRegistrant> registrantModels = new List<CSISIntegrationModels.CsisRegistrant>();
        
        String registrationStatus = null;
        
        if (attendeeWithStatus != null) {
            registrationStatus = attendeeWithStatus.conference360__Registration_Status__c;
            CSISIntegrationModels.CsisRegistrant statusRegistrantModel = new CSISIntegrationModels.CsisRegistrant(attendeeWithStatus);
            registrantModels.add(statusRegistrantModel);
        } else if (attendees != null && !attendees.isEmpty()) {
            registrationStatus = attendees[0].conference360__Registration_Status__c;
            CSISIntegrationModels.CsisRegistrant registrantModel = new CSISIntegrationModels.CsisRegistrant(attendees[0]);
            registrantModels.add(registrantModel);
        }
        
        CSISIntegrationModels.setRegistrationStatus(registrationStatus);
        
        CSISIntegrationModels.CsisOrderData orderModel = new CSISIntegrationModels.CsisOrderData(orderDoc);
        
        if (registrationStatus == 'Canceled') {
            orderModel.OrderStatus = 'X';
        }
        
        if (attendeeWithStatus == null && attendees != null && !attendees.isEmpty() && registrantModels.size() < attendees.size()) {
            for (Integer i = 1; i < attendees.size(); i++) {
                CSISIntegrationModels.CsisRegistrant registrantModel = new CSISIntegrationModels.CsisRegistrant(attendees[i]);
                registrantModels.add(registrantModel);
            }
        }

        if (registrantModels.isEmpty()) {
    orderModel.OrderType = 'SO';
    
    if (String.isBlank(orderModel.OrderAccount) && orderDoc.conference360__Event__c != null) {
        try {
            conference360__Event__c event = [
                SELECT Id, conference360__Organizer_Account__r.Computed_ID__c
                FROM conference360__Event__c
                WHERE Id = :orderDoc.conference360__Event__c
                LIMIT 1
            ];
            
            if (event != null && event.conference360__Organizer_Account__r != null) {
                orderModel.OrderAccount = event.conference360__Organizer_Account__r.Computed_ID__c;
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error getting event account: ' + ex.getMessage());
        }
    }
} else {
    orderModel.OrderType = 'ER';
}

        for (bt_stripe__Line_Item__c lineItem : lineItems) {
            CSISIntegrationModels.OrderItem itemModel = new CSISIntegrationModels.OrderItem(lineItem);
            orderModel.OrderItems.add(itemModel);
        }
        
        CSISIntegrationModels.CSISPayload payload = new CSISIntegrationModels.CSISPayload();
        payload.data.orderData = orderModel;
        payload.data.registrants = registrantModels.isEmpty() ? null : registrantModels;
        
        String jsonBody = JSON.serialize(payload);
        System.debug('CSIS Order JSON Payload: ' + jsonBody);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:CSIS_Endpoint');
        req.setMethod('POST');
        req.setBody(jsonBody);
        req.setTimeout(120000);

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('CSIS Order callout response: ' + res.getBody());
            
            boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
            
            if (success) {
                updateOrderIntegrationStatus(orderDoc.Id);
            } else {
                System.debug(LoggingLevel.ERROR, 'Failed to send order to CSIS: ' + res.getStatusCode() + ': ' + res.getBody());
            }
            
            return success;
        } catch(Exception ex) {
            System.debug('CSIS Order callout exception: ' + ex.getMessage());
            return false;
        }
    }
    
    @future
    private static void updateOrderIntegrationStatus(Id orderId) {
        try {
            bt_stripe__Sales_Document__c orderToUpdate = new bt_stripe__Sales_Document__c(
                Id = orderId,
                Integration_Done__c = true,
                Date_Time_Sent_To_CSIS__c = Datetime.now()
            );
            
            update orderToUpdate;
        } catch (Exception ex) {
            System.debug('Error updating order integration status: ' + ex.getMessage());
        }
    }
}