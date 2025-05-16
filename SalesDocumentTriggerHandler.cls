public class SalesDocumentTriggerHandler {
    public static Set<Id> processedDocIds = new Set<Id>();
    private static Boolean isExecuting = false;
    
    public static void handleBeforeInsert(List<bt_stripe__Sales_Document__c> newDocs) {
        for (bt_stripe__Sales_Document__c doc : newDocs) {
            if (String.isBlank(doc.externalId__c)) {
                doc.externalId__c = String.valueOf(DateTime.now().getTime()) + '-' + 
                                   String.valueOf(Math.round(Math.random() * 10000));
            }
        }
    }
    
    public static void handleAfterInsert(List<bt_stripe__Sales_Document__c> newDocs) {
    }
    
    public static void handleAfterUpdate(List<bt_stripe__Sales_Document__c> newDocs, Map<Id, bt_stripe__Sales_Document__c> oldMap) {
            if (CSISIntegrationManager.shouldSkipParentTrigger() || CSISIntegrationManager.isLineItemProcessing()) {
                CSISIntegrationManager.setSkipParentTrigger(false);
            return;
        }
        if (isExecuting || CSISIntegrationManager.isLineItemProcessing()) return;
        isExecuting = true;
        
        try {
            List<Id> docsToProcess = new List<Id>();
            
            for (bt_stripe__Sales_Document__c doc : newDocs) {
                if (processedDocIds.contains(doc.Id)) {
                    continue;
                }
                
                bt_stripe__Sales_Document__c oldDoc = oldMap.get(doc.Id);
                
                Boolean hasLineItems = hasLineItems(doc.Id);
                
                if (String.isNotBlank(doc.externalId__c) && doc.conference360__Event__c != null &&
                    hasLineItems && !OrderTriggerHandler.processedOrderIds.contains(doc.Id) &&
                    (doc.bt_stripe__Payment_Status__c != oldDoc.bt_stripe__Payment_Status__c ||
                     doc.bt_stripe__Balance_Paid_Amount__c != oldDoc.bt_stripe__Balance_Paid_Amount__c ||
                     doc.bt_stripe__Balance_Due_Amount__c != oldDoc.bt_stripe__Balance_Due_Amount__c ||
                     doc.bt_stripe__Total_Amount__c != oldDoc.bt_stripe__Total_Amount__c ||
                     !doc.Integration_Done__c)) {
                    
                    docsToProcess.add(doc.Id);
                    processedDocIds.add(doc.Id);
                    OrderTriggerHandler.processedOrderIds.add(doc.Id);
                }
            }
            
            if (!docsToProcess.isEmpty() && !CSISIntegrationManager.isLineItemProcessing()) {
                if (!System.isFuture() && !System.isBatch()) {
                    sendInvoicesToCSISFuture(docsToProcess);
                }
            }
        } finally {
            isExecuting = false;
        }
    }
    
    private static Boolean hasLineItems(Id docId) {
        Integer itemCount = [
            SELECT COUNT() 
            FROM bt_stripe__Line_Item__c 
            WHERE bt_stripe__Sales_Document__c = :docId
        ];
        return itemCount > 0;
    }
    
    @future(callout=true)
    public static void sendInvoicesToCSISFuture(List<Id> docIds) {
        if (CSISIntegrationManager.isLineItemProcessing()) return;
        
        sendInvoicesToCSIS(docIds);
    }
    
public static void sendInvoicesToCSIS(List<Id> docIds) {
    if (docIds == null || docIds.isEmpty() || CSISIntegrationManager.isLineItemProcessing()) {
        return;
    }
    
    try {
        List<bt_stripe__Sales_Document__c> documents = [
            SELECT Id, externalId__c, Name
            FROM bt_stripe__Sales_Document__c 
            WHERE Id IN :docIds
        ];
        
        for (bt_stripe__Sales_Document__c doc : documents) {
            if (String.isNotBlank(doc.externalId__c) && 
                !CSISIntegrationManager.isRecordProcessed(doc.externalId__c) &&
                !CSISOrderQueueable.isIdInProgress(doc.externalId__c)) {
                CSISIntegration.sendOrderToCsis(doc.externalId__c);
                CSISIntegrationManager.markRecordProcessed(doc.externalId__c);
            }
        }
    } catch (Exception ex) {
        System.debug(LoggingLevel.ERROR, 'Error sending documents to CSIS: ' + ex.getMessage());
    }
}
}