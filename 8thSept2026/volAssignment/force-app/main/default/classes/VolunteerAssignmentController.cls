public with sharing class VolunteerAssignmentController {
    /*
    	Fetch Event
		work type def map
		eligible students
		**getAssignmentCounts
		mapOFStudent w.r.t. already assigned workLoad.
 			x______________________________
		
	*/

    public static String assignVolunteers(Id volunteerWorkId) {

         
        // Fetch Event
        // will create Evewnt selector for this 
        Event__c work = [ SELECT Id, Work_Type__c, Primary_Category__c, Required_Student_Count__c, Status__c FROM Event__c
            				WHERE Id = :volunteerWorkId
            				LIMIT 1];

        Integer volunteersNeeded = Integer.valueOf(work.Required_Student_Count__c);
        if (volunteersNeeded <= 0)
            return 'Failed';
        
        // will create Work type def selector
        Map<String, Decimal> workloadWeights =  new Map<String, Decimal>();
        for (Workload_Defination__c workDef : Workload_Defination__c.getAll().values()) {
            workloadWeights.put(
                workDef.Name,
                workDef.Weight__c
            );
        }
        
         
        // Fetch eligible students
        List<Student__c> students = getEligibleStudents(work.Primary_Category__c);

        if (students.isEmpty()) 
            return 'Failed';

         
        // Fetch existing workload
        Map<Id, Integer> assignmentCountByStudent = getAssignmentCounts(students);
        
        Map<Id, Decimal> weightedWorkloadByStudent = getWeightedWorkload(students, workloadWeights);
        // till here am having StudentId, amt of workLoad 
                 return '';
    }


    private static List<Student__c> getEligibleStudents( String primaryCategory) {
        Set<String> eligibleCategories = new Set<String>{'Senior'};
        if(primaryCategory == 'Sub-Junior') 
            eligibleCategories.add('Sub-Junior');
        if(primaryCategory == 'Junior') {
            eligibleCategories.add('Sub-Junior');
            eligibleCategories.add('Junior');            
        }

        return [SELECT Id, Name, Category__c, Active__c, Volunteer__c FROM Student__c
                    WHERE Active__c = true
                            AND Volunteer__c = true
                            AND Category__c IN :eligibleCategories
        ];
    }

    private static Map<Id, Integer> getAssignmentCounts(List<Student__c> students) {
        Map<Id, Student__c> mapOfStudents = new Map<Id, Student__c>(students);
        Set<Id> studentIds = mapOfStudents.keySet();

        Map<Id, Integer> result = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Student__c studentId,
                   COUNT(Id) assignmentCount
            FROM Assigned_Volunteer__c
            WHERE Student__c IN :studentIds
            GROUP BY Student__c
        ]) {
			System.debug('ar ' + ar);
            result.put(
                (Id)ar.get('studentId'),
                Integer.valueOf(
                    String.valueOf(ar.get('assignmentCount'))
                )
            );
        }

        return result;
    }

    private static Map<Id, Decimal> getWeightedWorkload(List<Student__c> students,Map<String, Decimal> weights) {
        Set<Id> studentIds = new Map<Id, Student__c>(students).keySet();

        Map<Id, Decimal> result = new Map<Id, Decimal>();

        for (Assigned_Volunteer__c assignment : [ SELECT Student__c, Event__r.Work_Type__c FROM Assigned_Volunteer__c WHERE Student__c IN :studentIds]) {
            Decimal weight = weights.get(assignment.Event__r.Work_Type__c);
            Decimal current = result.containsKey(assignment.Student__c)? 
                				result.get(assignment.Student__c): 
            					0;
            result.put(
                assignment.Student__c,
                current + weight
            );
        }

        return result;
    }
}