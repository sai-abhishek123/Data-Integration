trigger AttendeeIntegrationTrigger on conference360__Attendee__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            AttendeeIntegrationHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AttendeeIntegrationHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}