public class TriggerContext {
    private static Boolean skipSalesDocumentTrigger = false;
    private static Boolean skipLineItemTrigger = false;
    private static Boolean skipAttendeeTrigger = false;
    private static Boolean skipEventTrigger = false;
    
    public static Boolean isSkipSalesDocumentTrigger() {
        return skipSalesDocumentTrigger;
    }
    
    public static void setSkipSalesDocumentTrigger(Boolean value) {
        skipSalesDocumentTrigger = value;
    }
    
    public static Boolean isSkipLineItemTrigger() {
        return skipLineItemTrigger;
    }
    
    public static void setSkipLineItemTrigger(Boolean value) {
        skipLineItemTrigger = value;
    }
    
    public static Boolean isSkipAttendeeTrigger() {
        return skipAttendeeTrigger;
    }
    
    public static void setSkipAttendeeTrigger(Boolean value) {
        skipAttendeeTrigger = value;
    }
    
    public static Boolean isSkipEventTrigger() {
        return skipEventTrigger;
    }
    
    public static void setSkipEventTrigger(Boolean value) {
        skipEventTrigger = value;
    }
}