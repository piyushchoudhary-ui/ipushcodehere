public without sharing class StudentSelector {

    public static List<Student__c> getEligibleStudents( Set<String> categories) {

        return [
            SELECT Id,
                   Name,
                   Category__c
            FROM Student__c
            WHERE Active__c = true
            AND Volunteer__c = true
            AND Category__c IN :categories
        ];
        //Assuming total number of Students are lesser then 50k
    }
}