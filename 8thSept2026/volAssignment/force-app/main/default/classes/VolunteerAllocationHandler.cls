public with sharing class VolunteerAllocationHandler {

    public static Map<Id, String> assignVolunteers(Set<Id> eventIds) {

        Map<Id, String> results = new Map<Id, String>();

        if (eventIds == null || eventIds.isEmpty()) {
            return results;
        }

        List<Event__c> events = EventSelector.getEventsByIds(eventIds);

        if (events.isEmpty()) {
            return results;
        }

        Set<String> categories = new Set<String>();

        for (Event__c eventRecord : events) {

            if (eventRecord.Required_Student_Count__c == null ||
                eventRecord.Required_Student_Count__c <= 0) {

                results.put(eventRecord.Id, 'Failed');
                continue;
            }

            categories.addAll(
                getEligibleCategories(eventRecord.Primary_Category__c
                )
            );
        }

        List<Student__c> students =
            StudentSelector.getEligibleStudents(categories);

        Set<Id> studentIds =
            new Map<Id, Student__c>(students).keySet();

        List<AggregateResult> workloadResults =
            AssignedVolunteerSelector.getWorkloadByStudentIds(
                studentIds
            );

        Map<Id, VolunteerWorkload> workloadMap =
            calculateWorkload(
                studentIds,
                workloadResults
            );

        Map<String, Integer> priorityMap =
            getWorkloadPriority();

        List<Assigned_Volunteer__c> assignments =
            new List<Assigned_Volunteer__c>();

        for (Event__c eventRecord : events) {

            if (eventRecord.Required_Student_Count__c == null ||
                eventRecord.Required_Student_Count__c <= 0) {
                continue;
            }

            Integer requiredCount =
                Integer.valueOf(
                    eventRecord.Required_Student_Count__c
                );

            Set<String> eligibleCategories =
                getEligibleCategories(
                    eventRecord.Primary_Category__c
                );

            List<VolunteerWorkload> candidates =
                new List<VolunteerWorkload>();

            for (Student__c student : students) {
            VolunteerWorkload workload = workloadMap.get(student.Id);

            if (workload == null)
                workload = new VolunteerWorkload(student.Id); //For the student having no assigned event...
            workload.studentName = student.Name; //includes no existing evnt assigned vols too
                workload.category = student.Category__c;
                candidates.add(workload);
            }
		System.debug('Hello candidates B ' + candidates);
        candidates.sort(new VolunteerComparator(priorityMap));
		System.debug('Hello candidates A ' + candidates);
        
        // Create Assgnmnt records
        List<Assigned_Volunteer__c> assignments = new List<Assigned_Volunteer__c>();

            for (Integer i = 0; i < requiredCount; i++) {

            VolunteerWorkload candidate = candidates[i];

                assignments.add(
                    new Assigned_Volunteer__c(
                        Event__c = eventRecord.Id,
                        Student__c = candidate.studentId,
                        Assigned_Date__c = Date.today()
                    )
                );
        }

        // insert 
            try {
                insert assignments;
            //return 'Success';
            } catch (DmlException ex) {
            //return 'Failed';
                    }
            return new Map<Id, String>();
    }

    private static Map<String, Integer> getWorkloadPriority() {

        Map<String, Integer> priorityMap = new Map<String, Integer>();
        for (Workload_Defination__c def : Workload_Defination__c.getAll().values()) {
            priorityMap.put(def.Name, Integer.valueOf(def.Weight__c));
            //cls, brn/ clg, 123
        }
        return priorityMap;
    }

    private static Set<String> getEligibleCategories(String primaryCategory) {

        Set<String> categories =
            new Set<String>{'Senior'};

        if (primaryCategory == 'Junior') {

            categories.add('Junior');
            categories.add('Sub-Junior');

        } else if (primaryCategory == 'Sub-Junior') {

            categories.add('Sub-Junior');
        }

        return categories;
    }

    private static Map<Id, VolunteerWorkload> calculateWorkload(
        Set<Id> studentIds,
        List<AggregateResult> workloadResults
    ) {

        Map<Id, VolunteerWorkload> result =
            new Map<Id, VolunteerWorkload>();

        for (Id studentId : studentIds) {

            result.put(
                studentId,
                new VolunteerWorkload(studentId)
            );
        }

        for (AggregateResult ar : workloadResults) {

            Id studentId =
                (Id) ar.get('studentId');

            String workType =
                (String) ar.get('workType');

            Integer count =
                Integer.valueOf(ar.get('total'));

            VolunteerWorkload workload =
                result.get(studentId);

            if (workload == null) {
                continue;
            }

            if (workType == 'Class') {

                workload.classCount = count;

            } else if (workType == 'Branch') {

                workload.branchCount = count;

            } else if (workType == 'Collage') {

                workload.collageCount = count;
            }
        }

        return result;
    }

    public class VolunteerWorkload {

        public Id studentId;
        public String studentName;
        public String category;
        public Integer classCount = 0;
        public Integer branchCount = 0;
        public Integer collageCount = 0;

        public VolunteerWorkload(Id studentId) {
            this.studentId = studentId;
        }
    }

    public class VolunteerComparator
        implements Comparator<VolunteerWorkload> {

        private Map<String, Integer> priorityMap;

        public VolunteerComparator(
            Map<String, Integer> priorityMap
        ) {
            this.priorityMap = priorityMap;
        }

        public Integer compare(VolunteerWorkload first, VolunteerWorkload second) {
            /*
            I   clg
            II  brnch
            III class
            */
            String firstPriorityType = getWorkTypeByPriority(1);
            Integer result = compareWorkload(first, second, firstPriorityType);
            if (result != 0) 
                return result;

            String secondPriorityType = getWorkTypeByPriority(2);
            result = compareWorkload(first, second, secondPriorityType);
            if (result != 0)
                return result;
            
            String thirdPriorityType = getWorkTypeByPriority(3);
            result = compareWorkload(first, second, thirdPriorityType);
            if (result != 0) 
                    return result;
                }
            }

            return 0;
        }


        private Integer compareWorkload( VolunteerWorkload first, VolunteerWorkload second, String workType) {
            Integer firstCount = getCount(first, workType);
            Integer secondCount = getCount(second, workType);

            if (firstCount < secondCount) {
                return -1;
            else if (firstCount > secondCount) 
                return 1;
			else
            return 0;
        }

		//sends number of event assigned of perticular wrktype
        private Integer getCount(VolunteerWorkload workload, String workType) {
            if (workType == 'Class')
                return workload.classCount;
            }

            if (workType == 'Branch') {
                return workload.branchCount;
            }

            if (workType == 'Collage') {
                return workload.collageCount;
            }

            return 0;
        }

        private String getWorkTypeByPriority(
            Integer priority
        ) {

            for (String workType : priorityMap.keySet()) {

                if (priorityMap.get(workType) == priority) {
                    return workType;
                }
            }

            return null;
        }
    }
}