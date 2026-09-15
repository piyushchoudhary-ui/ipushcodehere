public with sharing class StudentSelector {

    public static List<Student__c> getEligibleStudents(
        Set<String> categories
    ) {

        if (categories == null || categories.isEmpty()) {
            return new List<Student__c>();
        }

        return [
            SELECT Id,
                   Name,
                   Category__c
            FROM Student__c
            WHERE Active__c = true
            AND Volunteer__c = true
            AND Category__c IN :categories
        ];
    }
}