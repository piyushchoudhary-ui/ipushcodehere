@IsTest
private class VolunteerAllocationControllerTest {

    @TestSetup
    static void setupData() {

        insert new List<Workload_Defination__c>{
            new Workload_Defination__c(Name = 'Class', Weight__c = 1),
            new Workload_Defination__c(Name = 'Branch', Weight__c = 2),
            new Workload_Defination__c(Name = 'Collage', Weight__c = 3)
        };

        insert new List<Student__c>{
            new Student__c(Name = 'Senior Student', Category__c = 'Senior', Active__c = true, Volunteer__c = true),
            new Student__c(Name = 'Junior Student', Category__c = 'Junior', Active__c = true, Volunteer__c = true),
            new Student__c(Name = 'Sub Junior Student', Category__c = 'Sub-Junior', Active__c = true, Volunteer__c = true)
        };
    }

    @IsTest
    static void testAssignVolunteersWithNullEventIdsRetunEmptyResult() {

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(null);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testAssignVolunteerWithEmptyEventIdsReturnEmptyResult() {

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(new List<Id>());
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testAssignVolunteerWithInvalidIdsReturnMessageInvalidEventIds() {

        List<Id> ids = new List<Id>{UserInfo.getUserId()};

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(ids);
        Test.stopTest();

        System.assertEquals(System.Label.Invalid_EventId_EventIds, result[0].statusMessage);
    }

    @IsTest
    static void testAssignVolunteerWithZeroRequiredStudentCountReturnFailedVolunteerAllocationNoRequiredCount() {

        Event__c eventRecord = new Event__c(
            Name = 'Zero Count Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 0,
            Work_Type__c = 'Class'
        );

        insert eventRecord;

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
                new List<Id>{ eventRecord.Id }
            );
        Test.stopTest();
        Integer assignVolunteerCount =  [SELECT COUNT()
                                            FROM Assigned_Volunteer__c
                                            WHERE Event__c = :eventRecord.Id
                                        ];
        System.assertEquals(false, result[0].isSuccess);
        System.assertEquals(eventRecord.Id, result[0].eventId);
        System.assertEquals(eventRecord.Name + ' ' +System.Label.Failed_Volunteer_Allocation_No_Required_Count, result[0].statusMessage);
        System.assertEquals(0, assignVolunteerCount);
    }

    @IsTest
    static void testAssignVolunteersJuniorCategoryAllocationReturnSuccessMessageAndAllocatedVolunteerIds() {

        Event__c eventRecord = new Event__c(
            Name = 'Junior Event',
            Primary_Category__c = 'Junior',
            Required_Student_Count__c = 2,
            Work_Type__c = 'Class'
        );

        insert eventRecord;

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
                new List<Id>{ eventRecord.Id }
            );
        Test.stopTest();

        Integer assignVolunteerCount =  [SELECT COUNT()
                                            FROM Assigned_Volunteer__c
                                            WHERE Event__c = :eventRecord.Id
                                        ];


        System.assertEquals(true, result[0].isSuccess);
        System.assertEquals(2, result[0].allocatedVolunteers.size());
        System.assertEquals(String.valueOf(result[0].allocatedVolunteers.size()) + ' ' + System.Label.New_Volunteers_Are_Now_Assigned, result[0].statusMessage);
        System.assertEquals(2, assignVolunteerCount);
    }

    @IsTest
    static void testAssignVolunteersSubJuniorCategoryAllocationReturnSuccessMessageAndAllocatedVolunteerIds() {

        Event__c eventRecord = new Event__c(
            Name = 'Sub Junior Event',
            Primary_Category__c = 'Sub-Junior',
            Required_Student_Count__c = 2,
            Work_Type__c = 'Branch'
        );

        insert eventRecord;

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
            new List<Id>{ eventRecord.Id }
        );
        Test.stopTest();

        Integer assignVolunteerCount =  [SELECT COUNT()
                                            FROM Assigned_Volunteer__c
                                            WHERE Event__c = :eventRecord.Id
                                        ];

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].isSuccess);
        System.assertEquals(2, result[0].allocatedVolunteers.size());
        System.assertEquals(2, assignVolunteerCount);
    }

    @IsTest
    static void testAssignVolunteersSeniorCategoryAllocationReturnSuccessMessageAndAllocatedVolunteerIds() {

        Event__c eventRecord = new Event__c(
            Name = 'Senior Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Class'
        );

        insert eventRecord;

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
                new List<Id>{ eventRecord.Id }
            );
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].isSuccess);
        System.assertEquals(1, result[0].allocatedVolunteers.size());

        Student__c assignedStudent = [
            SELECT Id, Category__c
            FROM Student__c
            WHERE Id IN (
                SELECT Student__c
                FROM Assigned_Volunteer__c
                WHERE Event__c = :eventRecord.Id
            )
            LIMIT 1
        ];

        System.assertEquals('Senior', assignedStudent.Category__c);
    }
    
    @IsTest
    static void testAssignVolunteersPartialAlreadyExistingVolunteersAllocationReturnSuccessMessageAndAllocatedVolunteerIds() {

        Event__c eventRecord = new Event__c(
            Name = 'Sub Junior Event',
            Primary_Category__c = 'Sub-Junior',
            Required_Student_Count__c = 2,
            Work_Type__c = 'Branch'
        );

        insert eventRecord;
        
        Student__c studentRecord = [SELECT Id FROM Student__c Where Name = 'Senior Student' LIMIT 1];
        
        insert new Assigned_Volunteer__c(
            Event__c = eventRecord.Id,
            Student__c = studentRecord.Id,
            Assigned_Date__c = Date.today()
        );

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
            new List<Id>{ eventRecord.Id }
        );
        Test.stopTest();

        Integer assignVolunteerCount =  [SELECT COUNT()
                                            FROM Assigned_Volunteer__c
                                            WHERE Event__c = :eventRecord.Id
                                        ];

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].isSuccess);
        System.assertEquals(1, result[0].allocatedVolunteers.size());
        System.assertEquals(2, assignVolunteerCount);
        System.assertEquals(result[0].statusMessage, '1 '+ System.Label.Volunteers_Are_Already_Assigned + ' 1 ' + System.Label.New_Volunteers_Are_Now_Assigned);
    }
    
    @IsTest
    static void testAssignVolunteersAlreadyFullyAssignedVolunteersAllocationReturnSuccessMessageAndAllocatedVolunteerIds() {

        Event__c eventRecord = new Event__c(
            Name = 'Sub Junior Event',
            Primary_Category__c = 'Sub-Junior',
            Required_Student_Count__c = 2,
            Work_Type__c = 'Branch'
        );

        insert eventRecord;
        
        Student__c seniorStudentRecord = [SELECT Id FROM Student__c Where Name = 'Senior Student' LIMIT 1];
        Student__c subJuniorStudentRecord = [SELECT Id FROM Student__c Where Name = 'Sub Junior Student' LIMIT 1];
        
        List<Assigned_Volunteer__c> existingAssignments = new List<Assigned_Volunteer__c>();
        existingAssignments.add( 
            new Assigned_Volunteer__c( 
            Event__c = eventRecord.Id,
            Student__c = seniorStudentRecord.Id,
            Assigned_Date__c = Date.today()
        ));
        existingAssignments.add( 
            new Assigned_Volunteer__c( 
            Event__c = eventRecord.Id,
            Student__c = subJuniorStudentRecord.Id,
            Assigned_Date__c = Date.today()
        ));
        insert existingAssignments;

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
            new List<Id>{ eventRecord.Id }
        );
        Test.stopTest();

        Integer assignVolunteerCount =  [SELECT COUNT()
                                            FROM Assigned_Volunteer__c
                                            WHERE Event__c = :eventRecord.Id
                                        ];

        System.assertEquals(false, result[0].isSuccess);
        System.assertEquals(2, assignVolunteerCount);
        System.assertEquals(result[0].statusMessage, System.Label.Already_Assigned_Required_Resources);
    }
    
    @IsTest
    static void testAssignVolunteersInsufficientVolunteerReturnFailedMessage() {

        Event__c eventRecord = new Event__c(
            Name = 'Insufficient Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 10,
            Work_Type__c = 'Class'
        );

        insert eventRecord;

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
            new List<Id>{ eventRecord.Id }
        );
        Test.stopTest();

        Integer assignVolunteerCount =  [SELECT COUNT()
                                            FROM Assigned_Volunteer__c
                                            WHERE Event__c = :eventRecord.Id
                                        ];

        System.assertEquals(1, result.size());
        System.assertEquals(false, result[0].isSuccess);
        System.assertEquals(0, assignVolunteerCount);
    }

    @IsTest
    static void testExistingClassWorkload() {

        Student__c seniorStudent = [SELECT Id
            FROM Student__c
            WHERE Name = 'Senior Student'
            LIMIT 1
        ];

        Event__c oldEvent = new Event__c(
            Name = 'Old Class Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Class'
        );

        Event__c newEvent = new Event__c(
            Name = 'New Class Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Class'
        );

        insert new List<Event__c>{ oldEvent, newEvent };

        insert new Assigned_Volunteer__c(
            Event__c = oldEvent.Id,
            Student__c = seniorStudent.Id,
            Assigned_Date__c = Date.today()
        );

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
                new List<Id>{ newEvent.Id }
            );
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].isSuccess);
    }

    @IsTest
    static void testExistingBranchWorkload() {

        Student__c seniorStudent = [SELECT Id
            FROM Student__c
            WHERE Name = 'Senior Student'
            LIMIT 1
        ];

        Event__c oldEvent = new Event__c(
            Name = 'Old Branch Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Branch'
        );

        Event__c newEvent = new Event__c(
            Name = 'New Branch Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Branch'
        );

        insert new List<Event__c>{ oldEvent, newEvent };

        insert new Assigned_Volunteer__c(
            Event__c = oldEvent.Id,
            Student__c = seniorStudent.Id,
            Assigned_Date__c = Date.today()
        );

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
                new List<Id>{ newEvent.Id }
            );
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].isSuccess);
    }

    @IsTest
    static void testExistingCollageWorkload() {

        Student__c seniorStudent = [SELECT Id
            FROM Student__c
            WHERE Name = 'Senior Student'
            LIMIT 1
        ];

        Event__c oldEvent = new Event__c(
            Name = 'Old Collage Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Collage'
        );

        Event__c newEvent = new Event__c(
            Name = 'New Collage Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Collage'
        );

        insert new List<Event__c>{ oldEvent, newEvent };
        insert new Assigned_Volunteer__c(
            Event__c = oldEvent.Id,
            Student__c = seniorStudent.Id,
            Assigned_Date__c = Date.today()
        );

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
                new List<Id>{ newEvent.Id }
            );
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].isSuccess);
    }
@IsTest
    static void testMultipleEvents() {

        Event__c event1 = new Event__c(
            Name = 'Multiple Event 1',
            Primary_Category__c = 'Junior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Class'
        );

        Event__c event2 = new Event__c(
            Name = 'Multiple Event 2',
            Primary_Category__c = 'Junior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Branch'
        );

        insert new List<Event__c>{
            event1,
            event2
        };

        Test.startTest();
        List<VolunteerAllocationService.AssignVolunteersResponse> result = VolunteerAllocationController.assignVolunteers(
            new List<Id>{event1.Id, event2.Id}
        );
        Test.stopTest();

        Integer assignmentCount = [SELECT COUNT()
                                    FROM Assigned_Volunteer__c
                                    WHERE Event__c IN :new Set<Id>{
                                        event1.Id,
                                        event2.Id
                                    }
                                ];   

        System.assertEquals(2, result.size());
        System.assertEquals(2, assignmentCount);
    }

    @IsTest
    static void testGetAllocatedVolunteersReturnAllocatedStudents() {

        Student__c seniorStudent = [SELECT Id
            FROM Student__c
            WHERE Name = 'Senior Student'
            LIMIT 1
        ];

        Event__c eventRecord = new Event__c(
            Name = 'Allocated Volunteer Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Class'
        );

        insert eventRecord;

        insert new Assigned_Volunteer__c(
            Event__c = eventRecord.Id,
            Student__c = seniorStudent.Id,
            Assigned_Date__c = Date.today()
        );

        Test.startTest();
        List<VolunteerAllocationService.VolunteerWorkload> result = VolunteerAllocationController.getAllocatedVolunteers(
            eventRecord.Id
        );
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(seniorStudent.Id, result[0].studentId);
        System.assertEquals('Senior Student', result[0].studentName);
        System.assertEquals('Senior', result[0].category);
        System.assertEquals(1, result[0].classCount);
    }

    @IsTest
    static void testGetAllocatedVolunteersWithNullEventIdReturnEmptyResult() {

        Test.startTest();
        List<VolunteerAllocationService.VolunteerWorkload> result = VolunteerAllocationController.getAllocatedVolunteers(null);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testDeleteAssignVolunteerReturnSuccess() {

        Student__c seniorStudent = [SELECT Id
            FROM Student__c
            WHERE Name = 'Senior Student'
            LIMIT 1
        ];

        Event__c eventRecord = new Event__c(
            Name = 'Delete Volunteer Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Class'
        );

        insert eventRecord;

        insert new Assigned_Volunteer__c(
            Event__c = eventRecord.Id,
            Student__c = seniorStudent.Id,
            Assigned_Date__c = Date.today()
        );

        Test.startTest();
        String result = VolunteerAllocationController.deleteAssignVolunteer(
            new List<Id>{ eventRecord.Id },
            new List<Id>{ seniorStudent.Id }
        );
        Test.stopTest();

        Integer assignVolunteerCount = [SELECT COUNT()
                                        FROM Assigned_Volunteer__c
                                        WHERE Event__c = :eventRecord.Id
                                    ];

        System.assertEquals('SUCCESS', result);
        System.assertEquals(0, assignVolunteerCount);
    }

    @IsTest
    static void testDeleteAssignVolunteerReturnFailedWhenAssignmentDoesNotExist() {

        Event__c eventRecord = new Event__c(
            Name = 'No Assignment Event',
            Primary_Category__c = 'Senior',
            Required_Student_Count__c = 1,
            Work_Type__c = 'Class'
        );

        insert eventRecord;

        Student__c seniorStudent = [SELECT Id
            FROM Student__c
            WHERE Name = 'Senior Student'
            LIMIT 1
        ];

        Test.startTest();
        String result = VolunteerAllocationController.deleteAssignVolunteer(
            new List<Id>{ eventRecord.Id },
            new List<Id>{ seniorStudent.Id }
        );
        Test.stopTest();

        System.assertEquals('FAILED', result);
    }

    @IsTest
    static void testCheckPermissionsReturnPermissionMap() {

        Test.startTest();
        Map<String, Boolean> result = VolunteerAllocationController.checkPermissions();
        Test.stopTest();

        System.assertEquals(true, result.containsKey('isHavingAssigningPermission'));
        System.assertEquals(true, result.containsKey('isHavingStudentNamePermission'));
        System.assertEquals(true, result.containsKey('isHavingStudentCategoryPermission'));
    }
}
