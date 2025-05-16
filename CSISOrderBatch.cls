// CSISOrderBatch.cls
global class CSISOrderBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private Boolean processNonIntegratedOnly = false;
    private String regAccountCode;
    private Boolean overallSuccess = true;
    private String query;
    
    public CSISOrderBatch() {
        this.processNonIntegratedOnly = false;
        buildQuery();
    }
    
    public CSISOrderBatch(Boolean processNonIntegratedOnly) {
        this.processNonIntegratedOnly = processNonIntegratedOnly;
        buildQuery();
    }
    
    public CSISOrderBatch(String regAccountCode) {
        this.regAccountCode = regAccountCode;
        buildQuery();
    }
    
    private void buildQuery() {
        query = 'SELECT Id, externalId__c, bt_stripe__Bill_To__r.Computed_ID__c, '
              + 'bt_stripe__Payment_Status__c, conference360__Event__r.externalId__c, '
              + 'bt_stripe__Total_Amount__c, bt_stripe__Balance_Paid_Amount__c, createdDate, '
              + 'bt_stripe__Balance_Due_Amount__c, LastModifiedDate, bt_stripe__Tax_Amount__c, '
              + 'conference360__Event__r.L3__c '
              + 'FROM bt_stripe__Sales_Document__c '
              + 'WHERE externalId__c != null';
        
        if (processNonIntegratedOnly) {
            query += ' AND Integration_Done__c = false';
        }
        
        if (String.isNotBlank(regAccountCode)) {
            query += ' AND bt_stripe__Bill_To__r.Computed_ID__c = \'' + String.escapeSingleQuotes(regAccountCode) + '\'';
        }
    }
    
    public static Id runBatch() {
        CSISOrderBatch batch = new CSISOrderBatch();
        return Database.executeBatch(batch, 25);
    }
    
    public static Id runBatchForNonIntegrated() {
        CSISOrderBatch batch = new CSISOrderBatch(true);
        return Database.executeBatch(batch, 25);
    }
    
    public static Id runBatchForRegAccountCode(String regAccountCode) {
        CSISOrderBatch batch = new CSISOrderBatch(regAccountCode);
        return Database.executeBatch(batch, 25);
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<bt_stripe__Sales_Document__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        
        // Process orders in smaller chunks to avoid governor limits
        Integer batchSize = 5;
        for (Integer i = 0; i < scope.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, scope.size());
            List<bt_stripe__Sales_Document__c> batch = new List<bt_stripe__Sales_Document__c>();
            
            for (Integer j = i; j < endIndex; j++) {
                batch.add(scope[j]);
            }
            
            for (bt_stripe__Sales_Document__c order : batch) {
                try {
                    Boolean success = CSISIntegration.sendOrderToCsis(order.externalId__c);
                    if (!success) {
                        overallSuccess = false;
                        System.debug('CSIS Order Integration failed for order: ' + order.externalId__c);
                    }
                } catch (Exception ex) {
                    overallSuccess = false;
                    System.debug('Exception processing order ' + order.externalId__c + ': ' + ex.getMessage());
                }
            }
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :BC.getJobId()
        ];
        
        System.debug('CSIS Order Batch job completed - Status: ' + job.Status 
                   + ', Items Processed: ' + job.JobItemsProcessed
                   + ', Total Items: ' + job.TotalJobItems
                   + ', Errors: ' + job.NumberOfErrors
                   + ', Overall Success: ' + overallSuccess);
    }
}