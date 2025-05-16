global class UngerboeckBatchProcessor implements Database.Batchable<String>, Database.AllowsCallouts {
    global String jwtToken;
    
    global UngerboeckBatchProcessor(String jwtToken) {
        this.jwtToken = jwtToken;
    }
    
    global Iterable<String> start(Database.BatchableContext bc) {
        return new List<String>{'start'};
    }
    
    global void execute(Database.BatchableContext bc, List<String> scope) {
        try {
            List<conference360__Event__c> events = UngerboeckAPIService.fetchEventsWithAccounts(jwtToken);
            if (!events.isEmpty()) {
                UngerboeckAPIService.saveRecordsInBatches(events);
                System.debug('Successfully processed ' + events.size() + ' events');
            }
        } catch (Exception e) {
            System.debug('Error in batch execution: ' + e.getMessage() + ' - ' + e.getStackTraceString());
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('Ungerboeck event and account synchronization complete.');
    }
}

