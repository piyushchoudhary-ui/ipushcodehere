public with sharing class StudentSelector {
    public static List<Student__c> getEligibleStudents(Set<String> eligibleCategories, Integer volunteerNeeded) {
        return [SELECT Id FROM Student__c 
                WHERE Category__c IN :eligibleCategories AND Volunteer__c = true AND Is_Active__c = true
                // LIMIT volunteerNeeded
                ];
    }
}