public with sharing class UngerboeckEventFetchController {
    
    private static String getStringValue(Map<String, Object> data, String key) {
        Object value = data.get(key);
        return value != null ? String.valueOf(value) : '';
    }
    
    private static String getStatusValue(Map<String, Object> data, String key) {
        String status = getStringValue(data, key);
        if (status == '30') {
            return 'Active';
        } else if (status == '40') {
            return 'Canceled';
        } else if (status == '35') {
            return 'On Hold';
        } else if (status == '28') {
            return 'Pending';
        } else if (status == '45') {
            return 'Closed';
        } else if (status == '50') {
            return 'Completed';
        } else if (status == '10') {
            return 'Request/Enquiry';
        }
        return '';
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

    @AuraEnabled
    public static conference360__Event__c fetchAndCreateUngerboeckEvent(
        String jwtToken, 
        String fullUrl
    ) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(fullUrl);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + jwtToken);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(60000);
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            if (response.getStatusCode() != 200) {
                throw new AuraHandledException('API call failed: ' + response.getStatus() + 
                    ' (Status Code: ' + response.getStatusCode() + ')');
            }
            
            Map<String, Object> eventData = 
                (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            
            return createSalesforceRecords(eventData);
            
        } catch (Exception e) {
            System.debug('Error fetching and creating Ungerboeck event: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    private static conference360__Event__c createSalesforceRecords(Map<String, Object> eventData) {
        User currentUser = [SELECT Id, ContactId, Name FROM User WHERE Id = :UserInfo.getUserId() ];
        
        List<conference360__Staff__c> staffRecords = new List<conference360__Staff__c>();
        
        if (currentUser.ContactId != null) {
            conference360__Staff__c coordinatorStaff = new conference360__Staff__c(
                conference360__Contact__c = currentUser.ContactId,
                conference360__Event__c = null 
            );
            staffRecords.add(coordinatorStaff);
            
            conference360__Staff__c secondCoordinatorStaff = new conference360__Staff__c(
                conference360__Contact__c = currentUser.ContactId,
                conference360__Event__c = null 
            );
            staffRecords.add(secondCoordinatorStaff);
            
            conference360__Staff__c thirdCoordinatorStaff = new conference360__Staff__c(
                conference360__Contact__c = currentUser.ContactId,
                conference360__Event__c = null 
            );
            staffRecords.add(thirdCoordinatorStaff);
            
            conference360__Staff__c fourthCoordinatorStaff = new conference360__Staff__c(
                conference360__Contact__c = currentUser.ContactId,
                conference360__Event__c = null 
            );
            staffRecords.add(fourthCoordinatorStaff);
        }
        
        conference360__Custom_Event_Tab__c customEventTab = new conference360__Custom_Event_Tab__c(
            Name = getStringValue(eventData, 'Note1').length() > 80 
                ? getStringValue(eventData, 'Note1').substring(0, 80) 
                : getStringValue(eventData, 'Note1'),
            conference360__Content__c = getStringValue(eventData, 'Note1')
        );
        
        conference360__Event__c newEvent = new conference360__Event__c(
            Name = getStringValue(eventData, 'Description').length() > 80 
                ? getStringValue(eventData, 'Description').substring(0, 80) 
                : getStringValue(eventData, 'Description'),
            conference360__Event_Start_Date__c = getDateValue(eventData, 'StartDate'),
            conference360__Event_End_Date__c = getDateValue(eventData, 'EndDate'),
            conference360__Event_Start_Time__c = getTimeValue(eventData, 'StartTime'),
            conference360__Event_End_Time__c = getTimeValue(eventData, 'EndTime'),
            conference360__Status__c = getStatusValue(eventData, 'Status'),
            conference360__Category__c = getStringValue(eventData, 'Indicator'),
            conference360__Organizer_Account__c = currentUser.ContactId != null 
                ? [SELECT AccountId FROM Contact WHERE Id = :currentUser.ContactId].AccountId : null,
            conference360__Organizer_Contact__c = currentUser.ContactId,
            OwnerId = UserInfo.getUserId()
        );
        
        insert newEvent;
        customEventTab.conference360__Event__c = newEvent.Id;
        insert customEventTab;
        
        if (!staffRecords.isEmpty()) {
            for (conference360__Staff__c staff : staffRecords) {
                staff.conference360__Event__c = newEvent.Id;
            }
            insert staffRecords;
        }
        
        return newEvent;
    }
}