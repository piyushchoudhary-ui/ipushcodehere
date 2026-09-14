public with sharing class AssignedVolunteerSelector {

    public static List<AggregateResult> getWorkloadByStudentIds(
        Set<Id> studentIds
    ) {

        if (studentIds == null || studentIds.isEmpty()) {
            return new List<AggregateResult>();
        }

        return [
            SELECT Student__c studentId,
                   Event__r.Work_Type__c workType,
                   COUNT(Id) total
            FROM Assigned_Volunteer__c
            WHERE Student__c IN :studentIds
            GROUP BY Student__c, Event__r.Work_Type__c
        ];
    }
}