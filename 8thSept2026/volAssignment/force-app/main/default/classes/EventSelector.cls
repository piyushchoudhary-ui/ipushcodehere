public without sharing class EventSelector {

    public static List<Event__c> getEventsByIds(List<Id> eventIds) {

        return [
            SELECT Id,
            	   Name, //adding name so that it can be include in the binded message
                   Work_Type__c,
                   Primary_Category__c,
                   Required_Student_Count__c,
                   Status__c
            FROM Event__c
            WHERE Id IN :eventIds
        ];
    }
}