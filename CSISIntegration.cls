public class CSISIntegration {
    public static final String CSIS_ENDPOINT = 'https://stage.apps.csis.wisc.edu/api/USI/PostRegistrationData';
    
    private static final String USERNAME = 'your_username_here';
    private static final String PASSWORD = 'your_password_here';
    
    public static Boolean sendEventsWithJWT(List<conference360__Event__c> events) {
        if (events == null || events.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'CSIS Integration: Invalid input - events empty');
            return false;
        }
        
        Boolean overallSuccess = true;
        
        for (conference360__Event__c event : events) {
            List<EventDataModel> eventModels = new List<EventDataModel>();
            Map<Id, List<RegistrantDataModel>> eventToRegistrantsMap = new Map<Id, List<RegistrantDataModel>>();
            
            eventModels.add(new EventDataModel(event));
            eventToRegistrantsMap.put(event.Id, new List<RegistrantDataModel>());
            
            List<conference360__Attendee__c> attendees = [
                SELECT conference360__Contact__r.externalId__c, Computed_ID__c,
                       conference360__Contact__r.FirstName, conference360__Contact__r.LastName, 
                       conference360__Contact__r.Title, conference360__Account__r.Name,
                       conference360__Contact__r.Address__Street__s, conference360__Contact__r.Address__City__s, 
                       conference360__Contact__r.Address__StateCode__s, conference360__Contact__r.Address__PostalCode__s, 
                       conference360__Contact__r.Address__CountryCode__s, conference360__Contact__r.Email, 
                       conference360__Contact__r.Phone, conference360__Contact__r.Fax,
                       conference360__Contact__r.AccountId, conference360__Event__r.externalId__c,
                       conference360__Event__c, conference360__Event__r.L3__c
                FROM conference360__Attendee__c
                WHERE conference360__Event__c = :event.Id
            ];
            
            for (conference360__Attendee__c attendee : attendees) {
                RegistrantDataModel registrantModel = new RegistrantDataModel(attendee);
                eventToRegistrantsMap.get(event.Id).add(registrantModel);
            }
            
            CSISPayloadWrapper payload = new CSISPayloadWrapper(eventModels, eventToRegistrantsMap);
            String jsonBody = JSON.serialize(payload);
            System.debug('CSIS JSON Payload for event ' + event.Id + ': ' + jsonBody);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(CSIS_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            
            String auth = USERNAME + ':' + PASSWORD;
            String encodedAuth = EncodingUtil.base64Encode(Blob.valueOf(auth));
            req.setHeader('Authorization', 'Basic ' + encodedAuth);
            
            req.setBody(jsonBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                System.debug('CSIS callout response for event ' + event.Id + ': ' + res.getBody());
                
                boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
                
                if (success) {
                    updateIntegrationStatus(new List<conference360__Event__c>{event}, attendees);
                } else {
                    overallSuccess = false;
                }
            } catch(Exception ex) {
                System.debug('CSIS callout exception for event ' + event.Id + ': ' + ex.getMessage());
                overallSuccess = false;
            }
        }
        
        return overallSuccess;
    }
    
    private static void updateIntegrationStatus(List<conference360__Event__c> events, List<conference360__Attendee__c> attendees) {
        try {
            List<conference360__Event__c> eventsToUpdate = new List<conference360__Event__c>();
            List<conference360__Attendee__c> attendeesToUpdate = new List<conference360__Attendee__c>();
            Datetime now = Datetime.now();
            
            for (conference360__Event__c event : events) {
                eventsToUpdate.add(new conference360__Event__c(
                    Id = event.Id,
                    integration_done__c = true,
                    date_time_sent_to_csis__c = now
                ));
            }
            
            for (conference360__Attendee__c attendee : attendees) {
                attendeesToUpdate.add(new conference360__Attendee__c(
                    Id = attendee.Id,
                    integration_done__c = true,
                    date_time_sent_to_csis__c = now
                ));
            }
            
            if (!eventsToUpdate.isEmpty() || !attendeesToUpdate.isEmpty()) {
                updateRecordsFuture(JSON.serialize(eventsToUpdate), JSON.serialize(attendeesToUpdate));
            }
        } catch (Exception ex) {
            System.debug('Error updating integration status: ' + ex.getMessage());
        }
    }
    
    @future
    private static void updateRecordsFuture(String serializedEvents, String serializedAttendees) {
        try {
            if (String.isNotBlank(serializedEvents)) {
                List<conference360__Event__c> events = 
                    (List<conference360__Event__c>)JSON.deserialize(serializedEvents, 
                                                                List<conference360__Event__c>.class);
                if (!events.isEmpty()) {
                    update events;
                    System.debug('Successfully updated ' + events.size() + ' events with integration status');
                }
            }
            
            if (String.isNotBlank(serializedAttendees)) {
                List<conference360__Attendee__c> attendees = 
                    (List<conference360__Attendee__c>)JSON.deserialize(serializedAttendees, 
                                                                    List<conference360__Attendee__c>.class);
                if (!attendees.isEmpty()) {
                    update attendees;
                    System.debug('Successfully updated ' + attendees.size() + ' attendees with integration status');
                }
            }
        } catch (Exception ex) {
            System.debug('Error in future update: ' + ex.getMessage());
        }
    }
    
    private static String getStatusCode(String status) {
        if (status == null) return null;
        if (status == 'Canceled') return '40';
        else if (status == 'Closed') return '45';
        else if (status == 'Completed') return '50';
        else if (status == 'On Hold') return '35';
        else if (status == 'Pending') return '28';
        else if (status == 'Request/Enquiry') return '10';
        else if (status == 'Active') return '30';
        else return status;
    }
    
    public class EventDataModel {
        public String EventID;
        public String EventDesc;
        public String EventClass;
        public String EventCategory;
        public String EventStartDate;
        public String EventEndDate;
        public String EventSearch;
        public String EventCustomerNumber;
        public String EventStatus;
        public String L3;
        public String WebAddress;

        public EventDataModel(conference360__Event__c ev) {
            System.debug('Idi ra event: ' + ev);
            System.debug('Account ID: ' + ev.conference360__Organizer_Account__c);
            System.debug('Account Relationship: ' + ev.conference360__Organizer_Account__c);
            System.debug('Computed ID: ' + ev.conference360__Organizer_Account__r.Acc_Number__c);
            this.EventID = ev.externalId__c;
            this.EventDesc = ev.Name;
            this.EventClass = ev.Department__r?.ATP_Id__c;
            this.EventCategory = ev.Fiscal_Year__c;
            this.EventStartDate = ev.conference360__Event_Start_Date__c != null ? 
                            Datetime.newInstance(ev.conference360__Event_Start_Date__c, Time.newInstance(0, 0, 0, 0)).format('M/d/yyyy h:mm:ss a') : null;
            this.EventEndDate = ev.conference360__Event_End_Date__c != null ? 
                            Datetime.newInstance(ev.conference360__Event_End_Date__c, Time.newInstance(0, 0, 0, 0)).format('M/d/yyyy h:mm:ss a') : null;
            this.EventSearch = ev.Course_Offering__r?.SectionNumber;
            this.EventCustomerNumber = ev.conference360__Organizer_Account__r.Acc_Number__c;
            this.EventStatus = getStatusCode(ev.conference360__Status__c);
            this.L3 = ev.L3__c ? 'YES' : 'NO';
            this.WebAddress = ev.conference360__Event_Page_URL__c;
        }
    }
    
    public class RegistrantDataModel {
        public String RegAccountCode;
        public String ExternalCode;
        public String FirstName;
        public String LastName;
        public String Title;
        public String CompanyName;
        public String AddressLine1;
        public String AddressLine2;
        public String AddressLine3;
        public String City;
        public String StateCode;
        public String PostalCode;
        public String CountryCode;
        public String EmailAddress;
        public String MainPhone;
        public String MainFax;
        public String RegSeq;
        public String EventId;
        public List<String> Credentials;
        public List<String> MergedAccountCodes;
        public String L3;
        
        public RegistrantDataModel(conference360__Attendee__c att) {
            this.RegAccountCode = att.conference360__Contact__r?.externalId__c;
            this.ExternalCode = att.Computed_ID__c;
            this.FirstName = att.conference360__Contact__r?.FirstName;
            this.LastName = att.conference360__Contact__r?.LastName;
            this.Title = att.conference360__Contact__r?.Title;
            this.CompanyName = att.conference360__Account__r?.Name;
            
            if (att.conference360__Contact__r?.Address__Street__s != null) {
                List<String> addressLines = att.conference360__Contact__r.Address__Street__s.split('\n');
                if (addressLines.size() > 0) this.AddressLine1 = addressLines[0];
                if (addressLines.size() > 1) this.AddressLine2 = addressLines[1];
                if (addressLines.size() > 2) this.AddressLine3 = addressLines[2];
            } else {
                this.AddressLine1 = null;
                this.AddressLine2 = null;
                this.AddressLine3 = null;
            }
            
            this.City = att.conference360__Contact__r?.Address__City__s;
            this.StateCode = att.conference360__Contact__r?.Address__StateCode__s;
            this.PostalCode = att.conference360__Contact__r?.Address__PostalCode__s;
            this.CountryCode = att.conference360__Contact__r?.Address__CountryCode__s;
            this.EmailAddress = att.conference360__Contact__r?.Email;
            
            if (att.conference360__Contact__r?.Phone != null) {
                this.MainPhone = att.conference360__Contact__r.Phone.replaceAll('[^0-9]', '');
            }
            
            if (att.conference360__Contact__r?.Fax != null) {
                this.MainFax = att.conference360__Contact__r.Fax.replaceAll('[^0-9]', '');
            }
            
            if (att.Computed_ID__c != null) {
                this.RegSeq = att.Computed_ID__c;
            }
            
            this.EventId = att.conference360__Event__r?.externalId__c;
            
            this.Credentials = null;
            this.MergedAccountCodes = null;
            
            this.L3 = att.conference360__Event__r?.L3__c ? 'YES' : 'NO';
        }
    }

    public class CSISPayloadWrapper {
        public Object data;
        
        public CSISPayloadWrapper(Object eventData) {
            if (eventData instanceof List<EventDataModel> && !((List<EventDataModel>)eventData).isEmpty()) {
                this.data = new Map<String,Object>{
                    'eventData' => ((List<EventDataModel>)eventData)[0],
                    'registrants' => null
                };
            } else {
                this.data = new Map<String,Object>{
                    'eventData' => eventData,
                    'registrants' => null
                };
            }
        }
        
        public CSISPayloadWrapper(List<EventDataModel> eventData, Map<Id, List<RegistrantDataModel>> eventToRegistrantsMap) {
            List<RegistrantDataModel> allRegistrants = new List<RegistrantDataModel>();
            
            EventDataModel singleEvent = null;
            if (!eventData.isEmpty()) {
                singleEvent = eventData[0];
                
                Id eventId = null;
                for (Id eId : eventToRegistrantsMap.keySet()) {
                    if (eventToRegistrantsMap.get(eId) != null && !eventToRegistrantsMap.get(eId).isEmpty()) {
                        eventId = eId;
                        allRegistrants = eventToRegistrantsMap.get(eId);
                        break;
                    }
                }
            }
            
            this.data = new Map<String,Object>{
                'eventData' => singleEvent,
                'registrants' => allRegistrants
            };
        }
    }
}