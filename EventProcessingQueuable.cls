public class EventProcessingQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<Id> eventIds;
    private List<List<Id>> attendeeIdsByEvent;
    private List<String> serializedEventModels;
    private List<List<String>> serializedRegistrantModelsByEvent;
    private Integer currentIndex = 0;
    private final Integer MAX_BATCH_SIZE = 5;
    
    public EventProcessingQueueable(List<Id> eventIds, List<List<Id>> attendeeIdsByEvent, 
                                    List<String> serializedEventModels, 
                                    List<List<String>> serializedRegistrantModelsByEvent) {
        this.eventIds = eventIds;
        this.attendeeIdsByEvent = attendeeIdsByEvent;
        this.serializedEventModels = serializedEventModels;
        this.serializedRegistrantModelsByEvent = serializedRegistrantModelsByEvent;
    }
    
    public void execute(QueueableContext context) {
        if (eventIds == null || eventIds.isEmpty() || currentIndex >= eventIds.size()) {
            return;
        }
        
        Integer endIndex = Math.min(currentIndex + MAX_BATCH_SIZE, eventIds.size());
        List<Id> processedEventIds = new List<Id>();
        List<Id> processedAttendeeIds = new List<Id>();
        
        for (Integer i = currentIndex; i < endIndex; i++) {
            Id eventId = eventIds[i];
            List<Id> attendeeIds = attendeeIdsByEvent[i];
            CSISIntegrationModels.EventDataModel eventModel = (CSISIntegrationModels.EventDataModel)JSON.deserialize(
                serializedEventModels[i], CSISIntegrationModels.EventDataModel.class);
            
            List<CSISIntegrationModels.CsisRegistrant> registrantModels = new List<CSISIntegrationModels.CsisRegistrant>();
            List<String> serializedRegistrants = serializedRegistrantModelsByEvent[i];
            
            for (String serializedRegistrant : serializedRegistrants) {
                CSISIntegrationModels.CsisRegistrant registrant = (CSISIntegrationModels.CsisRegistrant)JSON.deserialize(
                    serializedRegistrant, CSISIntegrationModels.CsisRegistrant.class);
                registrantModels.add(registrant);
            }
            
            CSISIntegrationModels.CSISPayload payload = new CSISIntegrationModels.CSISPayload();
            payload.data.eventData = eventModel;
            payload.data.registrants = registrantModels.isEmpty() ? null : registrantModels;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Test_CSIS');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));
            req.setTimeout(120000);
            
            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                System.debug('CSIS callout response for event ' + eventId + ': ' + res.getBody());
                
                boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
                
                if (success) {
                    processedEventIds.add(eventId);
                    processedAttendeeIds.addAll(attendeeIds);
                } else {
                    System.debug(LoggingLevel.ERROR, 'Failed to send event to CSIS: ' + res.getStatusCode() + ': ' + res.getBody());
                }
            } catch(Exception ex) {
                System.debug('CSIS callout exception for event ' + eventId + ': ' + ex.getMessage());
            }
        }
        
        if (!processedEventIds.isEmpty() || !processedAttendeeIds.isEmpty()) {
            // Update integration status directly without @future method
            updateIntegrationStatusDirectly(processedEventIds, processedAttendeeIds);
        }
        
        currentIndex = endIndex;
        
        if (currentIndex < eventIds.size()) {
            System.enqueueJob(new EventProcessingQueueable(eventIds, attendeeIdsByEvent, 
                                                          serializedEventModels, serializedRegistrantModelsByEvent));
        }
    }
    
    // Direct update method to be used within Queueable context instead of @future method
    private void updateIntegrationStatusDirectly(List<Id> eventIds, List<Id> attendeeIds) {
        try {
            List<conference360__Event__c> eventsToUpdate = new List<conference360__Event__c>();
            List<conference360__Attendee__c> attendeesToUpdate = new List<conference360__Attendee__c>();
            Datetime now = Datetime.now();
            
            for (Id eventId : eventIds) {
                eventsToUpdate.add(new conference360__Event__c(
                    Id = eventId,
                    Event_Data_Sent_to_CSIS__c = true,
                    CSIS_Transmission_Timestamp__c = now
                ));
            }
            
            for (Id attendeeId : attendeeIds) {
                attendeesToUpdate.add(new conference360__Attendee__c(
                    Id = attendeeId,
                    integration_done__c = true,
                    date_time_sent_to_csis__c = now
                ));
            }
            
            if (!eventsToUpdate.isEmpty()) {
                update eventsToUpdate;
            }
            
            if (!attendeesToUpdate.isEmpty()) {
                update attendeesToUpdate;
            }
        } catch (Exception ex) {
            System.debug('Error updating integration status: ' + ex.getMessage());
        }
    }
}