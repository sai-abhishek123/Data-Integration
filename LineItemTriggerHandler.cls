public class LineItemTriggerHandler {
    private static Boolean isExecuting = false;
    
    public static void handleAfterChange(Set<Id> salesDocIds) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            CSISIntegrationManager.setSkipParentTrigger(true);
            CSISIntegrationManager.setLineItemProcessing(true);
            
            if (!salesDocIds.isEmpty()) {
                processOrdersForIntegration(salesDocIds);
            }
        } finally {
            isExecuting = false;
        }
    }
    
    
    @future
    public static void processOrdersForIntegration(Set<Id> salesDocIds) {
        try {
            List<bt_stripe__Sales_Document__c> orders = [
                SELECT Id, externalId__c, Integration_Done__c
                FROM bt_stripe__Sales_Document__c
                WHERE Id IN :salesDocIds
                AND conference360__Event__c != null
                AND externalId__c != null
            ];
            
            List<bt_stripe__Sales_Document__c> docsToUpdate = new List<bt_stripe__Sales_Document__c>();
            List<String> orderExternalIds = new List<String>();
            
            for (bt_stripe__Sales_Document__c order : orders) {
                docsToUpdate.add(new bt_stripe__Sales_Document__c(
                    Id = order.Id,
                    Integration_Done__c = false
                ));
                
                if (String.isNotBlank(order.externalId__c)) {
                    orderExternalIds.add(order.externalId__c);
                }
            }
            
            if (!docsToUpdate.isEmpty()) {
                update docsToUpdate;
                
                if (!orderExternalIds.isEmpty() && !Test.isRunningTest()) {
                    System.enqueueJob(new CSISOrderQueueable(orderExternalIds));
                } else if (Test.isRunningTest()) {
                    CSISIntegrationManager.setLineItemProcessing(false);
                }
            } else {
                CSISIntegrationManager.setLineItemProcessing(false);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error updating orders for integration: ' + ex.getMessage());
            CSISIntegrationManager.setLineItemProcessing(false);
            CSISIntegrationManager.setSkipParentTrigger(false);
        }
    }
}