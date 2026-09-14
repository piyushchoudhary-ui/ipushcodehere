public with sharing class EventSelector {

    public static List<Event__c> getEventsByIds(Set<Id> eventIds) {

        return [
            SELECT Id,
                   Work_Type__c,
                   Primary_Category__c,
                   Required_Student_Count__c,
                   Status__c
            FROM Event__c
            WHERE Id IN :eventIds
        ];
    }
}