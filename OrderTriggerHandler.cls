public class OrderTriggerHandler {
    public static Set<Id> processedOrderIds = new Set<Id>();
    
    public static void handleAfterInsert(List<bt_stripe__Sales_Document__c> newOrders) {
    }
    
    public static void handleAfterUpdate(List<bt_stripe__Sales_Document__c> newOrders, Map<Id, bt_stripe__Sales_Document__c> oldMap) {

        if (CSISIntegrationManager.shouldSkipParentTrigger() || CSISIntegrationManager.isLineItemProcessing()) {
                        CSISIntegrationManager.setSkipParentTrigger(false);
                        return;
}

        if (CSISIntegrationManager.isLineItemProcessing()) return;
        
        List<bt_stripe__Sales_Document__c> ordersToSync = new List<bt_stripe__Sales_Document__c>();
        
        for (bt_stripe__Sales_Document__c newOrder : newOrders) {
            if (processedOrderIds.contains(newOrder.Id)) {
                continue;
            }
            
            bt_stripe__Sales_Document__c oldOrder = oldMap.get(newOrder.Id);
            
            if (hasRelevantChanges(newOrder, oldOrder)) {
                ordersToSync.add(newOrder);
                processedOrderIds.add(newOrder.Id);
                SalesDocumentTriggerHandler.processedDocIds.add(newOrder.Id);
            }
        }
        
        if (!ordersToSync.isEmpty() && !CSISIntegrationManager.isLineItemProcessing()) {
            sendOrdersToCsis(ordersToSync);
        }
    }
    
    private static Boolean hasRelevantChanges(bt_stripe__Sales_Document__c newOrder, 
                                             bt_stripe__Sales_Document__c oldOrder) {
        return newOrder.bt_stripe__Total_Amount__c != oldOrder.bt_stripe__Total_Amount__c ||
               newOrder.bt_stripe__Balance_Paid_Amount__c != oldOrder.bt_stripe__Balance_Paid_Amount__c ||
               newOrder.bt_stripe__Payment_Status__c != oldOrder.bt_stripe__Payment_Status__c ||
               newOrder.bt_stripe__Bill_To__c != oldOrder.bt_stripe__Bill_To__c ||
               newOrder.conference360__Event__c != oldOrder.conference360__Event__c ||
               false;
    }
    
    private static void sendOrdersToCsis(List<bt_stripe__Sales_Document__c> orders) {
        List<String> orderExternalIds = new List<String>();
        
        for (bt_stripe__Sales_Document__c order : orders) {
            if (String.isNotBlank(order.externalId__c) && order.conference360__Event__c != null) {
                orderExternalIds.add(order.externalId__c);
            }
        }
        
        if (!orderExternalIds.isEmpty() && !CSISIntegrationManager.isLineItemProcessing()) {
            if (!Test.isRunningTest()) {
                sendOrdersFuture(orderExternalIds);
            } else {
                for (String orderExternalId : orderExternalIds) {
                    CSISIntegrationManager.processOrder(orderExternalId, false);
                }
            }
        }
    }
@future(callout=true)
private static void sendOrdersFuture(List<String> orderExternalIds) {
    if (CSISIntegrationManager.isLineItemProcessing()) return;
    
    List<String> filteredIds = new List<String>();
    for (String orderExternalId : orderExternalIds) {
        if (!CSISOrderQueueable.isIdInProgress(orderExternalId)) {
            try {
                CSISIntegration.sendOrderToCsis(orderExternalId);
            } catch (Exception ex) {
                System.debug('Error processing order ' + orderExternalId + ': ' + ex.getMessage());
            }
        }
    }
}
}