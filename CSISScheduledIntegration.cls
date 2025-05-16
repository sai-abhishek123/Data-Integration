global class CSISScheduledIntegration implements Schedulable, Database.AllowsCallouts {

    global void execute(SchedulableContext sc) {
        List<conference360__Event__c> events = [
            SELECT Id, externalId__c, Name, Fiscal_Year__c,
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c,
                   conference360__Status__c, L3__c, conference360__Event_Page_URL__c,
                   Department__r.ATP_Id__c, Course_Offering__r.SectionNumber,
                   conference360__Organizer_Account__r.Computed_ID__c
            FROM conference360__Event__c
            WHERE Integration_Pending__c = true
            LIMIT 1000
        ];

        if (!events.isEmpty()) {
            // Make Callout
            CSISIntegration.sendEventsWithJWT(events, CSISIntegration.getJWT());

            // Mark processed records as completed
            for (conference360__Event__c ev : events) {
                ev.Integration_Pending__c = false;
            }
            update events;
        }
    }
}
