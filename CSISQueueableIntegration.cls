public class CSISQueueableIntegration implements Queueable, Database.AllowsCallouts {

    // CSIS API credentials.
    // For production, consider storing these securely using Named Credentials or Custom Settings.
    private static final String CSIS_USER = 'your_user_id';       // Replace with your CSIS user ID.
    private static final String CSIS_PASSWORD = 'your_password';    // Replace with your CSIS password.
    
    private Set<Id> eventIds;
    
    // Constructor that accepts the set of event record Ids.
    public CSISQueueableIntegration(Set<Id> eventIds) {
        this.eventIds = eventIds;
    }
    
    // Execute method runs when the job is dequeued.
    public void execute(QueueableContext context) {
        // Query event records from the custom object.
        List<conference360__Event__c> events = [
            SELECT
                externalId__c,
                Name,
                Fiscal_Year__c,
                conference360__Event_Start_Date__c,
                conference360__Event_End_Date__c,
                conference360__Status__c,
                L3__c,
                Custom_Event_Page_URL__c,
                Department__r.ATP_Id__c,
                Course_Offering__r.SectionNumber,
                conference360__Organizer_Account__r.Computed_ID__c
            FROM conference360__Event__c
            WHERE Id IN :eventIds
        ];
        
        // Map each event record to our data model.
        List<EventDataModel> models = new List<EventDataModel>();
        for (conference360__Event__c eventRecord : events) {
            models.add(new EventDataModel(eventRecord));
        }
        
        // Build the payload in the required format.
        // If there's one event, eventData is a single object; otherwise, it's an array.
        CSISPayloadWrapper payload;
        if (models.size() == 1) {
            payload = new CSISPayloadWrapper(models[0]);
        } else {
            payload = new CSISPayloadWrapper(models);
        }
       
        String jsonBody = JSON.serialize(payload);
        
        // Debug the JSON payload before performing the HTTP callout.
        System.debug('CSIS JSON Payload: ' + jsonBody);
        
        // Prepare the HTTP request.
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://wwwtest.admin.csis.wisc.edu/CSIS-2/');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        // Build the Basic Authentication header.
        String credentials = CSIS_USER + ':' + CSIS_PASSWORD;
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(credentials));
        req.setHeader('Authorization', authHeader);
        
        req.setBody(jsonBody);
        
        // Perform the HTTP callout.
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('CSIS callout succeeded: ' + res.getBody());
            } else {
                System.debug('CSIS callout failed with status: ' + res.getStatus());
            }
        } catch(Exception ex) {
            System.debug('CSIS callout exception: ' + ex.getMessage());
        }
    }
    
    /**
     * Helper method to format DateTime values.
     * Outputs a string in the "M/d/yyyy h:mm:ss a" format (e.g., "3/13/2025 12:00:00 AM"),
     * matching the sample JSON you provided.
     */
    public static String formatDateTime(DateTime dt) {
        if (dt == null) {
            return null;
        }
        return dt.format('M/d/yyyy h:mm:ss a');
    }
    
    /**
     * Inner class representing the event data model.
     */
    public class EventDataModel {
        public Integer EventID;            // USI unique event identifier.
        public String EventDesc;           // Event name.
        public String EventClass;          // Event class.
        public String EventCategory;       // Event fiscal year.
        public String EventStartDate;      // Formatted event start date.
        public String EventEndDate;        // Formatted event end date.
        public String EventSearch;         // CSIS event identifier.
        public String EventCustomerNumber; // Department/Campus Unit identifier.
        public String EventStatus;         // Event status (e.g., "30" for Active).
        public String L3;                  // L3/NetID provisioning indicator.
        public String WebAddress;          // Registration URL.
        
        // Constructor mapping the conference360__Event__c record to the data model.
        public EventDataModel(conference360__Event__c eventRecord) {
            this.EventID = (eventRecord.externalId__c != null) 
                           ? Integer.valueOf(eventRecord.externalId__c) 
                           : null;
            this.EventDesc = eventRecord.Name;
            this.EventClass = (eventRecord.Department__r != null) 
                              ? eventRecord.Department__r.ATP_Id__c 
                              : null;
            this.EventCategory = eventRecord.Fiscal_Year__c;
            this.EventStartDate = CSISQueueableIntegration.formatDateTime(eventRecord.conference360__Event_Start_Date__c);
            this.EventEndDate = CSISQueueableIntegration.formatDateTime(eventRecord.conference360__Event_End_Date__c);
            this.EventSearch = (eventRecord.Course_Offering__r != null) 
                               ? eventRecord.Course_Offering__r.SectionNumber 
                               : null;
            this.EventCustomerNumber = (eventRecord.conference360__Organizer_Account__r != null) 
                                       ? eventRecord.conference360__Organizer_Account__r.Computed_ID__c 
                                       : null;
            this.EventStatus = eventRecord.conference360__Status__c;
            this.L3 = (eventRecord.L3__c) ? 'YES' : 'NO';
            this.WebAddress = eventRecord.Custom_Event_Page_URL__c;
        }
    }
    
    public class CSISPayloadWrapper {
        public CSISPayload data;
        
        // Constructor accepts either a single event object or a list of events.
        public CSISPayloadWrapper(Object eventData) {
            data = new CSISPayload(eventData);
        }
    }
    
    /**
     * Class representing the inner payload structure.
     */
    public class CSISPayload {
        public Object eventData;
        public Object registrants;
        
        public CSISPayload(Object eventData) {
            this.eventData = eventData;
            this.registrants = null;
        }
    }
}
