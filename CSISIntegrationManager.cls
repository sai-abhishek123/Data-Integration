public class CSISIntegrationManager {
    @TestVisible
    private static Boolean isProcessingLineItems = false;
    private static Set<String> processedExternalIds = new Set<String>();
    private static Boolean skipParentTrigger = false;
    
    public static void setSkipParentTrigger(Boolean skip) {
        skipParentTrigger = skip;
    }

    public static void resetState() {
        isProcessingLineItems = false;
        skipParentTrigger = false;
        processedExternalIds.clear();
    }

    public static Boolean shouldSkipParentTrigger() {
        return skipParentTrigger;
    }

    public static Boolean isRecordProcessed(String externalId) {
        if (String.isBlank(externalId)) return false;
        if (isProcessingLineItems) return true;
        return processedExternalIds.contains(externalId);
    }
    
    public static void markRecordProcessed(String externalId) {
        if (String.isBlank(externalId)) return;
        processedExternalIds.add(externalId);
    }
    
    public static void setLineItemProcessing(Boolean isProcessing) {
        isProcessingLineItems = isProcessing;
        System.debug('LineItem processing flag set to: ' + isProcessing);
    }
    
    public static Boolean isLineItemProcessing() {
        return isProcessingLineItems;
    }
    
    public static Boolean processOrder(String externalId, Boolean fromLineItem) {
        if (String.isBlank(externalId) || isRecordProcessed(externalId)) {
            return false;
        }
        
        markRecordProcessed(externalId);
        
        if (!fromLineItem) {
            return false;
        }
        
        return CSISIntegration.sendOrderToCsis(externalId);
    }
}