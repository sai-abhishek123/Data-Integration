public with sharing class UngerboeckAPIService {
    private static final String PERSON_ACCOUNT_RECORD_TYPE = '012Hp000002YZSkIAO';
    private static final String ORGANIZATION_RECORD_TYPE = '012Hp000002YZSfIAO';
    
    public static void processEvents(String jwt) {
        List<conference360__Event__c> events = fetchEventsWithAccounts(jwt);
        saveRecordsInBatches(events);
    }
    
    public static List<conference360__Event__c> fetchEventsWithAccounts(String jwtToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://uw.ungerboeck.com/test/api/v1/Events/10?search=Category+eq+%272023%27$page_size=3');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + jwtToken);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        List<conference360__Event__c> eventList = new List<conference360__Event__c>();
        Map<String, Account> accountsToUpsert = new Map<String, Account>();
        
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
            
            List<String> accountNumbers = new List<String>();
            for (Object itemObj : items) {
                Map<String, Object> eventData = (Map<String, Object>) itemObj;
                String accountNumber = getStringValue(eventData, 'Account');
                if (String.isNotBlank(accountNumber) && !accountsToUpsert.containsKey(accountNumber)) {
                    accountNumbers.add(accountNumber);
                }
            }
            
            for (String accountNumber : accountNumbers) {
                Account accountRecord = fetchAndCreateAccount(accountNumber, jwtToken);
                if (accountRecord != null) {
                    accountsToUpsert.put(accountNumber, accountRecord);
                }
            }
            
            if (!accountsToUpsert.isEmpty()) {
                upsertAccounts(accountsToUpsert.values());
                
                Map<String, Id> accountIdMap = new Map<String, Id>();
                for (Account acc : [SELECT Id, AccountNumber, Acc_Number__c FROM Account 
                                   WHERE AccountNumber IN :accountNumbers OR Acc_Number__c IN :accountNumbers]) {
                    if (acc.AccountNumber != null) {
                        accountIdMap.put(acc.AccountNumber, acc.Id);
                    }
                    if (acc.Acc_Number__c != null) {
                        accountIdMap.put(acc.Acc_Number__c, acc.Id);
                    }
                }
                
                for (String accNum : accountsToUpsert.keySet()) {
                    if (accountIdMap.containsKey(accNum)) {
                        accountsToUpsert.get(accNum).Id = accountIdMap.get(accNum);
                    }
                }
            }
            
            for (Object itemObj : items) {
                Map<String, Object> eventData = (Map<String, Object>) itemObj;
                String accountNumber = getStringValue(eventData, 'Account');
                Account accountRecord = accountsToUpsert.get(accountNumber);
                
                String name = getStringValue(eventData, 'Description');
                String eventId = getStringValue(eventData, 'EventID');
                String contactId = null;
                String userId = UserInfo.getUserId();
                
                conference360__Event__c newEvent = new conference360__Event__c(
                    Event_Name__c = name,
                    Name = truncateString(getStringValue(eventData, 'Description'), 80),
                    // EventID__c = eventId,
                    conference360__Event_Start_Date__c = getDateValue(eventData, 'StartDate'),
                    conference360__Event_End_Date__c = getDateValue(eventData, 'EndDate'),
                    conference360__Event_Start_Time__c = getTimeValue(eventData, 'StartTime'),
                    conference360__Event_End_Time__c = getTimeValue(eventData, 'EndTime'),
                    conference360__Status__c = getStatusValue(eventData, 'Status'),
                    conference360__Category__c = getStringValue(eventData, 'Category'),
                    conference360__Organizer_Contact__c = contactId,
                    OwnerId = userId
                );
                
                if (accountRecord != null && accountRecord.Id != null) {
                    System.debug('Setting Organizer Account: ' + accountRecord.Id + ' for event: ' + name);
                    newEvent.conference360__Organizer_Account__c = accountRecord.Id;
                } else {
                    System.debug('No account found for account number: ' + accountNumber);
                }
                
                eventList.add(newEvent);
            }
            
        } else {
            System.debug('API call failed: ' + res.getStatus() + ' - ' + res.getBody());
        }
        
        return eventList;
    }
    
    private static Account fetchAndCreateAccount(String accountNumber, String jwtToken) {
        if (String.isBlank(accountNumber)) {
            return null;
        }
        List<Account> existingAccounts = [
            SELECT Id, AccountNumber, Acc_Number__c
            FROM Account 
            WHERE AccountNumber = :accountNumber OR Acc_Number__c = :accountNumber
            LIMIT 1
        ];
        
        if (!existingAccounts.isEmpty()) {
            return existingAccounts[0];
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://uw.ungerboeck.com/test/api/v1/Accounts/10/' + accountNumber);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + jwtToken);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(60000);

        System.debug('Fetching account data for: ' + accountNumber);
        System.debug('Request URL: ' + req.getEndpoint());
        
        Http http = new Http();
        HttpResponse res;
        
        try {
            res = http.send(req);
        } catch (Exception e) {
            System.debug('Error fetching account data: ' + e.getMessage());
            return null;
        }
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> accountData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String accountClass = getStringValue(accountData, 'Class');
            Id recordTypeId;
            Boolean isPersonAccount = (accountClass == 'P');
            if (isPersonAccount) {
                recordTypeId = PERSON_ACCOUNT_RECORD_TYPE;
            } else {
                recordTypeId = ORGANIZATION_RECORD_TYPE;
            }
            
            Account newAccount = new Account(
                RecordTypeId = recordTypeId,
                AccountNumber = accountNumber,
                Acc_Number__c = accountNumber, 
                Phone = getStringValue(accountData, 'Phone'),
                Fax = getStringValue(accountData, 'Fax'),
                Website = getStringValue(accountData, 'Website'),
                conference360__Email__c = getStringValue(accountData, 'Email'),
                BillingStreet = formatBillingAddress(accountData),
                BillingCity = getStringValue(accountData, 'City'),
                BillingState = getStringValue(accountData, 'State'),
                BillingPostalCode = getStringValue(accountData, 'PostalCode'),
                BillingCountry = getStringValue(accountData, 'Country'),
                Type = getStringValue(accountData, 'Type'),
                Description = getStringValue(accountData, 'Search'),
                OwnerId = UserInfo.getUserId()
            );
            
            if (isPersonAccount) {
                String fullName = getStringValue(accountData, 'Name');
                List<String> nameParts = fullName.split(' ', 2);
                if (nameParts.size() > 0) {
                    newAccount.FirstName = nameParts[0];
                    if (nameParts.size() > 1) {
                        newAccount.LastName = nameParts[1];
                    } else {
                        newAccount.LastName = fullName;
                    }
                } else {
                    newAccount.LastName = 'Unknown';
                }
                
                Date birthDate = getDateValue(accountData, 'BirthDate');
                if (birthDate != null) {
                    newAccount.PersonBirthdate = birthDate;
                }
                
            } else {
                newAccount.Name = getStringValue(accountData, 'Name');
            }
            
            return newAccount;
        } else {
            System.debug('Account API call failed: ' + res.getStatus() + ' - ' + res.getBody());
            return null;
        }
    }
    
    private static String formatBillingAddress(Map<String, Object> accountData) {
        String address1 = getStringValue(accountData, 'Address1');
        String address2 = getStringValue(accountData, 'Address2');
        String address3 = getStringValue(accountData, 'Address3');
        
        List<String> addressParts = new List<String>();
        if (String.isNotBlank(address1)) addressParts.add(address1);
        if (String.isNotBlank(address2)) addressParts.add(address2);
        if (String.isNotBlank(address3)) addressParts.add(address3);
        
        return String.join(addressParts, '\n');
    }
    
    private static void upsertAccounts(List<Account> accounts) {
        if (accounts.isEmpty()) {
            return;
        }
        
        Set<String> accountNumbers = new Set<String>();
        for (Account acc : accounts) {
            accountNumbers.add(acc.AccountNumber);
        }
        
        Map<String, Id> existingAccountIds = new Map<String, Id>();
        for (Account acc : [SELECT Id, AccountNumber, Acc_Number__c FROM Account 
                           WHERE AccountNumber IN :accountNumbers OR Acc_Number__c IN :accountNumbers]) {
            if (acc.AccountNumber != null) {
                existingAccountIds.put(acc.AccountNumber, acc.Id);
            }
            if (acc.Acc_Number__c != null) {
                existingAccountIds.put(acc.Acc_Number__c, acc.Id);
            }
        }
        
        List<Account> accountsToInsert = new List<Account>();
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Account acc : accounts) {
            if (existingAccountIds.containsKey(acc.AccountNumber)) {
                acc.Id = existingAccountIds.get(acc.AccountNumber);
                accountsToUpdate.add(acc);
            } else {
                accountsToInsert.add(acc);
            }
        }
        
        try {
            if (!accountsToInsert.isEmpty()) {
                insert accountsToInsert;
            }
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
        } catch (DmlException e) {
            System.debug('Error processing accounts: ' + e.getMessage());
        }
    }
    
    public static void saveRecordsInBatches(List<conference360__Event__c> events) {
        if (events.isEmpty()) {
            return;
        }
        
        Integer batchSize = 200;
        for (Integer i = 0; i < events.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, events.size());
            List<conference360__Event__c> batch = new List<conference360__Event__c>();
            for (Integer j = i; j < endIdx; j++) {
                batch.add(events[j]);
            }
            try {
                insert batch;
                System.debug('Successfully inserted ' + batch.size() + ' events');
            } catch (DmlException e) {
                System.debug('Insert failed for batch starting at index ' + i + ': ' + e.getMessage());
                for (Integer j = 0; j < batch.size(); j++) {
                    System.debug('Event at index ' + (i + j) + ': ' + batch[j]);
                }
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

