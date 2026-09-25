public with sharing class VolunteerAllocationService {

    public static List<AssignVolunteersResponse> assignVolunteers(List<Id> eventIds) {
    
        List<AssignVolunteersResponse> results = new List<AssignVolunteersResponse>();
            
        if (eventIds == null || eventIds.isEmpty()) {
            return results;
        }
    
        List<Event__c> events = EventSelector.getEventsByIds(eventIds);
            
        if (events.isEmpty()) {
            results.add(new AssignVolunteersResponse(
                null,
                false,
                System.Label.Invalid_EventId_EventIds 
            ));
            return results;
        }
    
        List<Assigned_Volunteer__c> existingAssignments = AssignedVolunteerSelector.getAssignedVolunteersByEventIds(eventIds);
    
        Map<Id, Integer> existingCountByEvent = new Map<Id, Integer>();
        Map<Id, Set<Id>> assignedStudentsByEvent = new Map<Id, Set<Id>>();
    
        for (Assigned_Volunteer__c assignment : existingAssignments) {
            Integer count = existingCountByEvent.get(assignment.Event__c);
            if (count == null) 
                count = 0;

            existingCountByEvent.put(assignment.Event__c, count + 1);
    
            if (!assignedStudentsByEvent.containsKey(assignment.Event__c)) 
                assignedStudentsByEvent.put(assignment.Event__c, new Set<Id>());
    
            assignedStudentsByEvent.get(assignment.Event__c).add(assignment.Student__c);
        }

        Set<String> categories = new Set<String>();
                
        for (Event__c eventRecord : events) {
            if (eventRecord.Required_Student_Count__c == null || eventRecord.Required_Student_Count__c <= 0) {
                results.add(new AssignVolunteersResponse(
                    eventRecord.Id, 
                    false,  
                    eventRecord.Name + ' ' + System.Label.Failed_Volunteer_Allocation_No_Required_Count
                ));
                continue;
            }
    
            Integer alreadyAssigned = existingCountByEvent.containsKey(eventRecord.Id)?
                                        existingCountByEvent.get(eventRecord.Id): 0;
            Integer requiredCount = Integer.valueOf(eventRecord.Required_Student_Count__c);
    
            if (alreadyAssigned >= requiredCount) {
                results.add(new AssignVolunteersResponse(
                    eventRecord.Id,
                    false,
                    System.Label.Already_Assigned_Required_Resources 
                ));
                continue;
            }
            categories.addAll(getEligibleCategories(eventRecord.Primary_Category__c));
        }
    
        List<Student__c> students = StudentSelector.getEligibleStudents(categories);
            
        if(students.isEmpty()) {
            results.add(new AssignVolunteersResponse(
                null,
                false,
                System.Label.No_Eligible_Students_Available 
            ));
            return results;
        }
            
        Set<Id> studentIds = new Map<Id, Student__c>(students).keySet();
            
        List<AggregateResult> workloadResults = AssignedVolunteerSelector.getWorkloadByStudentIds(
                studentIds
        );
        //here we have workload result for the students already having some tasks...
        Map<Id, VolunteerWorkload> studentWorkloadMap =
            calculateWorkload(
                studentIds,
                workloadResults
            );
        //workload map doesn't consist students with no tasks yet
        Map<String, Integer> priorityMap = getWorkloadPriority();//here we have custom setting deatails
    
        List<Assigned_Volunteer__c> assignments = new List<Assigned_Volunteer__c>();
            
        for (Event__c eventRecord : events) {
            if (eventRecord.Required_Student_Count__c == null ||
                eventRecord.Required_Student_Count__c <= 0) {
                continue;
            }
    
            Integer requiredCount = Integer.valueOf(eventRecord.Required_Student_Count__c);
    
            Integer alreadyAssigned = existingCountByEvent.containsKey(eventRecord.Id)? 
                                        existingCountByEvent.get(eventRecord.Id): 0;
    
            Integer remainingCount = requiredCount - alreadyAssigned;
    
            if (remainingCount <= 0) {
                continue;
            }
    
            Set<String> eligibleCategories = getEligibleCategories(eventRecord.Primary_Category__c);
    
            List<VolunteerWorkload> candidates = new List<VolunteerWorkload>();
                
            List<VolunteerWorkload> allocatedCandidates = new List<VolunteerWorkload>();
    
            Set<Id> alreadyAssignedStudentIds = assignedStudentsByEvent.get(eventRecord.Id);
                
            for (Student__c student : students) {
    
                if (alreadyAssignedStudentIds != null && alreadyAssignedStudentIds.contains(student.Id)) {
                    continue;
                }
                if (!eligibleCategories.contains(student.Category__c)) {
                    continue;
                }
                VolunteerWorkload workload = studentWorkloadMap.get(student.Id);
                workload.studentName = student.Name;
                workload.category = student.Category__c;
                candidates.add(workload);
            }
            if (candidates.size() < remainingCount) {
                results.add(new AssignVolunteersResponse(
                    eventRecord.Id, 
                    false,  
                    eventRecord.Name + ' ' + System.Label.Failed_Eligible_Volunteers_Are_Less
                ));
                continue;
            }
            //rearranging based on the priority
            candidates.sort(new VolunteerComparator(priorityMap));
    
            for (Integer i = 0; i < remainingCount; i++) {
                VolunteerWorkload candidate = candidates[i];
                allocatedCandidates.add(candidate);
                assignments.add(
                    new Assigned_Volunteer__c(
                        Event__c = eventRecord.Id,
                        Student__c = candidate.studentId,
                        Assigned_Date__c = Date.today()
                    )
                );
                    
                updateWorkload(
                    candidate,
                    eventRecord.Work_Type__c
                );
            }
    
            String successMessage;
    
            if (alreadyAssigned > 0) {
                successMessage = alreadyAssigned + ' ' +
                    System.Label.Volunteers_Are_Already_Assigned + ' ' + remainingCount + ' ' +
                    System.Label.New_Volunteers_Are_Now_Assigned;
            } else {
                successMessage = remainingCount + ' ' + System.Label.New_Volunteers_Are_Now_Assigned;
            }
                
            AssignVolunteersResponse successAssignment = new AssignVolunteersResponse(
                    eventRecord.Id, 
                    true,  
                    successMessage
            );
    
            successAssignment.allocatedVolunteers = allocatedCandidates;
            results.add(successAssignment);
        }
    
        Database.SaveResult[] saveResults = Database.insert(assignments, false);
        
        for (Integer i = 0; i < saveResults.size(); i++) {       
            if (!saveResults[i].isSuccess()) {
                Assigned_Volunteer__c failedAssignment = assignments[i];
                    
                for (AssignVolunteersResponse response : results) {
                    if (response.eventId == failedAssignment.Event__c) {
                        response.isSuccess = false;
                        response.statusMessage = System.Label.Failed_DML + ' ' + saveResults[i].getErrors()[0].getMessage();
                        response.allocatedVolunteers = new List<VolunteerWorkload>();
                        break;
                    }
                }
            }
        }
            
        return results;
    }

    public static string deleteAssignVolunteer(List<Id> eventIds, List<Id> studentIds) {
        List<Assigned_Volunteer__c> assigneesToDelete = AssignedVolunteerSelector.deleteAssignedVolunteer(eventIds, studentIds);
        if(!assigneesToDelete.isEmpty()) {
            delete assigneesToDelete;            
            return 'SUCCESS';
        }
        return 'FAILED';
    }

    public static List<VolunteerWorkload> getAllocatedVolunteers(Id eventId) {
    
        if (eventId == null) {
            return new List<VolunteerWorkload>();
        }
    
        List<Assigned_Volunteer__c> assignments = AssignedVolunteerSelector.getAssignedVolunteersByEventIds(
                new List<Id>{ eventId }
        );
        
        if (assignments.isEmpty()) {
            return new List<VolunteerWorkload>();
        }
    
        Set<Id> studentIds = new Set<Id>();
    
        Map<Id, Student__c> studentMap = new Map<Id, Student__c>();
    
        for (Assigned_Volunteer__c assignment : assignments) {
            studentIds.add(assignment.Student__c);
            studentMap.put(assignment.Student__c, assignment.Student__r);
        }
    
        List<AggregateResult> workloadResults = AssignedVolunteerSelector.getWorkloadByStudentIds(studentIds);
    
        Map<Id, VolunteerWorkload> workloadMap = calculateWorkload(studentIds, workloadResults);

        List<VolunteerWorkload> result = new List<VolunteerWorkload>();
    
        for (Id studentId : studentIds) {
            VolunteerWorkload workload = workloadMap.get(studentId);
            Student__c student = studentMap.get(studentId);
            workload.studentName = student.Name;
            workload.category = student.Category__c;
            result.add(workload);
        }
    
        return result;
    }

    public static Map<String, Boolean> checkPermissions() {
        Map<String, Boolean> permissions = new Map<String, Boolean>();
        permissions.put('isHavingAssigningPermission', Schema.sObjectType.Assigned_Volunteer__c.isCreateable());
        permissions.put('isHavingStudentNamePermission', Schema.sObjectType.Student__c.fields.Name.isAccessible());
        permissions.put('isHavingStudentCategoryPermission', Schema.sObjectType.Student__c.fields.Category__c.isAccessible());        
        return permissions;
    }
    
    private static Map<String, Integer> getWorkloadPriority() {

        Map<String, Integer> priorityMap = new Map<String, Integer>();
        List<Schema.PicklistEntry> workTypes = Event__c.Work_Type__c.getDescribe().getPicklistValues();
        Set<Integer> weightSet = new Set<Integer>();
        for(Schema.PicklistEntry workType : workTypes) 
            priorityMap.put(workType.getValue(), 0);
        for(Integer i = 1; i <= workTypes.size(); i++) 
            weightSet.add(i);
        //My map will already be having the needed keys, but if those priority 
        for (Workload_Defination__c def : Workload_Defination__c.getAll().values()) {
            if(priorityMap.containsKey(def.Name) && weightSet.contains(Integer.valueOf(def.Weight__c))) {
                priorityMap.put(def.Name, Integer.valueOf(def.Weight__c));
                weightSet.remove(Integer.valueOf(def.Weight__c));//preventing repeatation
            }
        }
        return priorityMap;
    }


    private static Set<String> getEligibleCategories( String primaryCategory) {

        Set<String> categories = new Set<String>{'Senior'};

        if (primaryCategory == 'Junior') {
            categories.add('Junior');
            categories.add('Sub-Junior');
        } else if (primaryCategory == 'Sub-Junior') {
            categories.add('Sub-Junior');
        }

        return categories;
    }

    private static Map<Id, VolunteerWorkload> calculateWorkload(Set<Id> studentIds, List<AggregateResult> workloadResults) {

        Map<Id, VolunteerWorkload> result = new Map<Id, VolunteerWorkload>();

        for (Id studentId : studentIds) {
            result.put(studentId, new VolunteerWorkload(studentId));
        }

        for (AggregateResult ar : workloadResults) {

            Id studentId = (Id) ar.get('studentId');
            String workType = (String) ar.get('workType');
            Integer count = Integer.valueOf(ar.get('total'));
            VolunteerWorkload workload = result.get(studentId);

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

    private static void updateWorkload(VolunteerWorkload workload, String workType) {
        if (workType == 'Class') {
            workload.classCount++;
        } else if (workType == 'Branch') {
            workload.branchCount++;
        } else if (workType == 'Collage') {
            workload.collageCount++;
        }
    }

    public class VolunteerWorkload {
        @AuraEnabled
        public Id studentId;
        @AuraEnabled
        public String studentName;
        @AuraEnabled
        public String category;
        @AuraEnabled
        public Integer classCount = 0;
        @AuraEnabled
        public Integer branchCount = 0;
        @AuraEnabled
        public Integer collageCount = 0;

        public VolunteerWorkload(Id studentId) {
            this.studentId = studentId;
        }
    }


    public class VolunteerComparator implements Comparator<VolunteerWorkload> {

        private Map<String, Integer> priorityMap;

        public VolunteerComparator(Map<String, Integer> priorityMap) {
            this.priorityMap = priorityMap;
        }
        
        public Integer compare(VolunteerWorkload first, VolunteerWorkload second) {

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

            // Fourth priority: alphabetical student name
            if (first.studentName != second.studentName) 
                return first.studentName.compareTo(
                    second.studentName
                );

            return 0;
        }

        private Integer compareWorkload(VolunteerWorkload first, VolunteerWorkload second, String workType) {
            Integer firstCount = getCount(first, workType);

            Integer secondCount = getCount(second, workType);
            
            if (firstCount < secondCount) {
                return -1;
            }
            if (firstCount > secondCount) {
                return 1;
            }
            
            return 0;
        }

        private Integer getCount(
            VolunteerWorkload workload,
            String workType
        ) {

            if (workType == 'Class') {
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

        private String getWorkTypeByPriority(Integer priority) {
            for (String workType : priorityMap.keySet()) {
                if (priorityMap.get(workType) == priority) {
                    return workType;
                }
            }
            return null;
        }
    }
    
    public class AssignVolunteersResponse {
        @AuraEnabled
        public Id eventId ;
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public String statusMessage;
        @AuraEnabled
        public List<VolunteerWorkload> allocatedVolunteers;
        
        public AssignVolunteersResponse(Id eventId, Boolean isSuccess, String statusMessage) {
            this.eventId = eventId;
            this.isSuccess = isSuccess;
            this.statusMessage = statusMessage;
        }
    }
}