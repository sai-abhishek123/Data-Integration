public class EventSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> eventIds;
    
    public EventSyncQueueable(List<Id> eventIds) {
        this.eventIds = eventIds;
    }
    
    public void execute(QueueableContext context) {
        List<conference360__Event__c> refreshedEvents = [
            SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                   Computed_Id_Account__c, Course_Offering__r.SectionNumber, 
                   conference360__Status__c, L3__c, conference360__Event_Page_URL__c,
                   conference360__Organizer_Account__c, integration_done__c
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        updateComputedIdAccountIfNeeded(refreshedEvents);
        
        List<conference360__Event__c> eventsToSend = new List<conference360__Event__c>();
        for (conference360__Event__c event : refreshedEvents) {
            if (event.integration_done__c != true && 
                String.isNotBlank(event.Computed_Id_Account__c) && 
                String.isNotBlank(event.externalId__c)) {
                eventsToSend.add(event);
            }
        }
        
        if (!eventsToSend.isEmpty()) {
            CSISIntegration.sendEventsWithJWT(eventsToSend);
        }
    }
    
    private void updateComputedIdAccountIfNeeded(List<conference360__Event__c> events) {
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
                
                event.Computed_Id_Account__c = accountMap.get(event.conference360__Organizer_Account__c).Computed_ID__c;
                
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
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Error updating Computed_Id_Account__c: ' + ex.getMessage());
            }
        }
    }
}