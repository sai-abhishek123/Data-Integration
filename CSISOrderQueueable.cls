public class CSISOrderQueueable implements Queueable, Database.AllowsCallouts {
    private List<String> orderExternalIds;
    private static Set<String> inProgressIds = new Set<String>();
    
    public CSISOrderQueueable(List<String> orderExternalIds) {
        this.orderExternalIds = orderExternalIds;
        for(String id : orderExternalIds) {
            inProgressIds.add(id);
        }
    }
    
    public CSISOrderQueueable(String orderExternalId) {
        this.orderExternalIds = new List<String>{orderExternalId};
        inProgressIds.add(orderExternalId);
    }
    
    public static Boolean isIdInProgress(String externalId) {
        return inProgressIds.contains(externalId);
    }
    
    public void execute(QueueableContext context) {
        try {
            for(String externalId : orderExternalIds) {
                try {
                    CSISIntegration.sendOrderToCsis(externalId);
                } finally {
                    inProgressIds.remove(externalId);
                }
            }
        } finally {
            CSISIntegrationManager.setLineItemProcessing(false);
            CSISIntegrationManager.setSkipParentTrigger(false);
        }
    }
}