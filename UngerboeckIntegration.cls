public with sharing class UngerboeckIntegration {
    public static void runIntegration(String jwt) {
        List<conference360__Event__c> events = fetchEvents(jwt);
        insertInBatches(events);
    }
    
    public static List<conference360__Event__c> fetchEvents(String jwtToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://uw.ungerboeck.com/test/api/v1/Events/10?search=Category+eq+%272022%27');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + jwtToken);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        List<conference360__Event__c> eventList = new List<conference360__Event__c>();
        
        if (res.getStatusCode() == 200) {
            Object parsedResponse = JSON.deserializeUntyped(res.getBody());
            List<Object> items = new List<Object>();
            if (parsedResponse instanceof Map<String, Object>) {
                Map<String, Object> resultMap = (Map<String, Object>) parsedResponse;
                if(resultMap.containsKey('Items')) {
                    items = (List<Object>) resultMap.get('Items');
                } else {
                    System.debug('Response is a Map but does not contain an Items key.');
                }
            } else if (parsedResponse instanceof List<Object>) {
                items = (List<Object>) parsedResponse;
            } else {
                System.debug('Unexpected JSON structure: ' + res.getBody());
            }
            
            for (Object itemObj : items) {
                Map<String, Object> eventData = (Map<String, Object>) itemObj;
                String name = getStringValue(eventData, 'Description');
                String eventId = getStringValue(eventData, 'EventID');
                String accountId = null;
                String contactId = null;
                String userId = UserInfo.getUserId(); 

                conference360__Event__c newEvent = new conference360__Event__c(
                    Event_Name__c= name,
                    //Name='a',
                    Name = truncateString(getStringValue(eventData, 'Description'), 80),
                    // EventID__c = eventId,
                    conference360__Event_Start_Date__c = getDateValue(eventData, 'StartDate'),
                    conference360__Event_End_Date__c = getDateValue(eventData, 'EndDate'),
                    conference360__Event_Start_Time__c = getTimeValue(eventData, 'StartTime'),
                    conference360__Event_End_Time__c = getTimeValue(eventData, 'EndTime'),
                    conference360__Status__c = getStatusValue(eventData, 'Status'),
                    conference360__Category__c = getStringValue(eventData, 'Category'),
                    // conference360__Organizer_Account__c = accountId,
                    // conference360__Organizer_Contact__c = contactId,
                    externalId__c = eventId,
                    OwnerId = userId
                );
                
                eventList.add(newEvent);
            }
        } else {
            System.debug('API call failed: ' + res.getStatus() + ' - ' + res.getBody());
        }
        
        return eventList;
    }
    
    public static void insertInBatches(List<conference360__Event__c> events) {
        Integer batchSize = 200;
        for (Integer i = 0; i < events.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, events.size());
            List<conference360__Event__c> batch = new List<conference360__Event__c>();
            for (Integer j = i; j < endIdx; j++) {
                batch.add(events[j]);
            }
            try {
                insert batch;
            } catch (DmlException e) {
                System.debug('Insert failed for batch starting at index ' + i + ': ' + e.getMessage());
            }
        }
    }
    
    private static String getStringValue(Map<String, Object> data, String key) {
        Object val = data.get(key);
        return (val != null) ? String.valueOf(val) : '';
    }
    
    private static Date getDateValue(Map<String, Object> data, String key) {
        String dateStr = getStringValue(data, key);
        return String.isNotBlank(dateStr) ? Date.valueOf(dateStr.split('T')[0]) : null;
    }
    
    private static Time getTimeValue(Map<String, Object> data, String key) {
        String timeStr = getStringValue(data, key);
        if (String.isNotBlank(timeStr)) {
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

    private static String truncateString(String value, Integer maxLength) {
        if (value != null && value.length() > maxLength) {
            return value.substring(0, maxLength);
        }
        return value;
    }
}