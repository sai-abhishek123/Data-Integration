/**
 * Asynchronous Batch Apex class to import Event records from Ungerboeck API
 * This class retrieves events from the specified endpoint and creates/updates
 * corresponding records in Salesforce
 * 
 * To execute this batch job:
 * String jwtToken = 'YOUR_JWT_TOKEN';
 * Database.executeBatch(new UngerboeckIntegrationBatch(jwtToken), 100);
 */
global class UngerboeckIntegrationBatch implements Database.Batchable<Map<String, Object>>, Database.AllowsCallouts, Database.Stateful {
    
    // API endpoint URL
    private final String apiEndpoint = 'https://uw.ungerboeck.com/test/api/v1/Events/10/search?query=Category+eq+%272023%27';
    
    // JWT Authentication token
    private final String jwtToken;
    
    // Store any errors that occur during processing
    private List<String> errors;
    
    // Constructor with JWT token
    global UngerboeckIntegrationBatch(String jwtToken) {
        this.errors = new List<String>();
        this.jwtToken = jwtToken;
    }
    
    /**
     * Start method for the batch job
     * Makes the HTTP callout to the API endpoint and returns the list of records to process
     */
    global Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> eventsToProcess = new List<Map<String, Object>>();
        
        try {
            // Create HTTP request
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(apiEndpoint);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            
            // Add JWT authentication token
            request.setHeader('Authorization', 'Bearer ' + this.jwtToken);
            
            // Send the request
            HttpResponse response = http.send(request);
            
            // Process successful response
            if (response.getStatusCode() == 200) {
                // Parse JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                // Extract events from the response
                // Adjust this based on the actual structure of your API response
                if (responseMap.containsKey('items')) {
                    List<Object> items = (List<Object>) responseMap.get('items');
                    for (Object item : items) {
                        eventsToProcess.add((Map<String, Object>) item);
                    }
                }
            } else {
                // Log error
                String errorMsg = 'API call failed with status code: ' + response.getStatusCode() + 
                                 ' and message: ' + response.getStatus() + 
                                 ' Body: ' + response.getBody();
                errors.add(errorMsg);
                System.debug(LoggingLevel.ERROR, errorMsg);
            }
        } catch (Exception e) {
            // Log exception
            String errorMsg = 'Exception in start method: ' + e.getMessage() + ' Stack trace: ' + e.getStackTraceString();
            errors.add(errorMsg);
            System.debug(LoggingLevel.ERROR, errorMsg);
        }
        
        return eventsToProcess;
    }
    
    /**
     * Execute method processes each batch of records
     */
    global void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        try {
            List<conference360__Event__c> eventsToUpsert = new List<conference360__Event__c>();
            
            for (Map<String, Object> eventData : scope) {
                // Create a conference360__Event__c record from the API data
                conference360__Event__c eventRecord = mapApiDataToEventRecord(eventData);
                if (eventRecord != null) {
                    eventsToUpsert.add(eventRecord);
                }
            }
            
            // Upsert the records to Salesforce
            if (!eventsToUpsert.isEmpty()) {
                List<Database.UpsertResult> results = Database.upsert(eventsToUpsert, conference360__Event__c.ID, false);
                
                // Process the results
                for (Integer i = 0; i < results.size(); i++) {
                    Database.UpsertResult result = results[i];
                    if (!result.isSuccess()) {
                        for (Database.Error err : result.getErrors()) {
                            String errorMsg = 'Error upserting record: ' + eventsToUpsert[i] + '. Error: ' + err.getStatusCode() + ': ' + err.getMessage();
                            errors.add(errorMsg);
                            System.debug(LoggingLevel.ERROR, errorMsg);
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Log exception
            String errorMsg = 'Exception in execute method: ' + e.getMessage() + ' Stack trace: ' + e.getStackTraceString();
            errors.add(errorMsg);
            System.debug(LoggingLevel.ERROR, errorMsg);
        }
    }
    
    /**
     * Finish method is called after all batches are processed
     */
    global void finish(Database.BatchableContext bc) {
        // Log completion
        System.debug(LoggingLevel.INFO, 'Ungerboeck import job completed');
        
        // If needed, you can add additional processing logic here
        if (!errors.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'Errors encountered during processing: ' + errors.size());
            for (String error : errors) {
                System.debug(LoggingLevel.ERROR, error);
            }
        }
    }
    
    /**
     * Helper method to map API data to conference360__Event__c record
     */
    private conference360__Event__c mapApiDataToEventRecord(Map<String, Object> eventData) {
        try {
            // Get the owner ID (current user or specific user)
            Id userId = UserInfo.getUserId(); // Default to current user
            
            // Get event description and ID
            String description = getStringValue(eventData, 'description');
            String eventId = getStringValue(eventData, 'id');
            
            // Create a new conference360__Event__c record
            conference360__Event__c newEvent = new conference360__Event__c(
                Name='a',
                Event_Name__c = description, // Using description as Name field
                conference360__Event_Start_Date__c = getDateValue(eventData, 'StartDate'),
                EventID__c = eventId,
                conference360__Event_End_Date__c = getDateValue(eventData, 'EndDate'),
                conference360__Event_Start_Time__c = getTimeValue(eventData, 'StartTime'),
                conference360__Event_End_Time__c = getTimeValue(eventData, 'EndTime'),
                conference360__Status__c = getStatusValue(eventData, 'Status'),
                conference360__Category__c = getStringValue(eventData, 'Category'),
                OwnerId = userId
            );
            
            return newEvent;
        } catch (Exception e) {
            String errorMsg = 'Error mapping API data to Event record: ' + e.getMessage();
            errors.add(errorMsg);
            System.debug(LoggingLevel.ERROR, errorMsg);
            return null;
        }
    }
    
    /**
     * Helper method to get the status value based on the code
     */
    private static String getStatusValue(Map<String, Object> data, String key) {
        String status = getStringValue(data, key);
        if (status == '30') return 'Active';
        if (status == '40') return 'Canceled';
        if (status == '35') return 'On Hold';
        if (status == '28') return 'Pending';
        if (status == '45') return 'Closed';
        if (status == '50') return 'Completed';
        if (status == '10') return 'Request/Enquiry';
        return '';
    }
    
    /**
     * Helper method to get a string value from the data map
     */
    private static String getStringValue(Map<String, Object> data, String key) {
        Object val = data.get(key);
        return (val != null) ? String.valueOf(val) : '';
    }
    
    /**
     * Helper method to get a Date value from the data map
     */
    private static Date getDateValue(Map<String, Object> data, String key) {
        String dateStr = getStringValue(data, key);
        return String.isNotBlank(dateStr) ? Date.valueOf(dateStr.split('T')[0]) : null;
    }
    
    /**
     * Helper method to get a Time value from the data map
     */
    private static Time getTimeValue(Map<String, Object> data, String key) {
        String timeStr = getStringValue(data, key);
        if (String.isNotBlank(timeStr) && timeStr.contains('T')) {
            List<String> timeParts = timeStr.split('T')[1].split(':');
            return Time.newInstance(
                Integer.valueOf(timeParts[0]),
                Integer.valueOf(timeParts[1]),
                0,
                0
            );
        }
        return null;
    }
}