global class CSISScheduledSync implements Schedulable {
    
    global void execute(SchedulableContext sc) {
        String query = 'SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, ' +
                      'conference360__Event_Start_Date__c, conference360__Event_End_Date__c, ' +
                      'Course_Offering__r.SectionNumber, conference360__Organizer_Account__r.Computed_ID__c, ' +
                      'conference360__Status__c, L3__c, Custom_Event_Page_URL__c, ' +
                      'Event_Data_Sent_to_CSIS__c, CSIS_Transmission_Timestamp__c ' +
                      'FROM conference360__Event__c ' +
                      'WHERE LastModifiedDate >= YESTERDAY ' +
                      'AND (Event_Data_Sent_to_CSIS__c = false OR Event_Data_Sent_to_CSIS__c = null)';
        
        Database.executeBatch(new CSISEventBatch(query), 100);
    }
}