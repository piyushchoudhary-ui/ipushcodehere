public without sharing class AssignedVolunteerSelector {

    public static List<AggregateResult> getWorkloadByStudentIds(
        Set<Id> studentIds
    ) {
        return [
            SELECT Student__c studentId,
                   Event__r.Work_Type__c workType,
                   COUNT(Id) total
            FROM Assigned_Volunteer__c
            WHERE Student__c IN :studentIds
            GROUP BY Student__c, Event__r.Work_Type__c
        ];
    }

    public static List<Assigned_Volunteer__c> deleteAssignedVolunteer(
        List<Id> eventIds, List<Id> studentIds
    ) {
        return [
            SELECT Id FROM Assigned_Volunteer__c 
                        WHERE Student__c IN :studentIds
                        AND Event__c IN :eventIds
        ];
    }
    
    public static List<Assigned_Volunteer__c> getAssignedVolunteersByEventIds(
        List<Id> eventIds
    ) {
        return [
            SELECT Id,
                   Event__c,
                   Student__c,
                   Student__r.Name,
                   Student__r.Category__c
            FROM Assigned_Volunteer__c
            WHERE Event__c IN :eventIds
        ];
    }
}
