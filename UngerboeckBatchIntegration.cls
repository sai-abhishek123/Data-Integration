global class UngerboeckBatchIntegration implements Database.Batchable<conference360__Event__c>, Database.AllowsCallouts {
    private String jwt;
    
    // Constructor accepting the JWT.
    public UngerboeckBatchIntegration(String jwt) {
        this.jwt = jwt;
    }
    
    // Query locator to retrieve all events.
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT
                externalId__c,
                Name,
                Fiscal_Year__c,
                conference360__Event_Start_Date__c,
                conference360__Event_End_Date__c,
                conference360__Status__c,
                L3__c,
                conference360__Event_Page_URL__c,
                Department__r.ATP_Id__c,
                Course_Offering__r.SectionNumber,
                conference360__Organizer_Account__r.Computed_ID__c
            FROM conference360__Event__c
        ]);
    }
    
    // Execute method that processes the batch.
    // To send all events in one call, run the batch with a scope
    // parameter equal to or greater than the total number of records.
    global void execute(Database.BatchableContext BC, List<conference360__Event__c> scope) {
        // Use the integration logic that uses JWT authentication.
        CSISIntegration.sendEventsWithJWT(scope, jwt);
    }
    
    // Optional finish method.
    global void finish(Database.BatchableContext BC) {
        System.debug('UngerboeckBatchIntegration batch job finished.');
    }
}
