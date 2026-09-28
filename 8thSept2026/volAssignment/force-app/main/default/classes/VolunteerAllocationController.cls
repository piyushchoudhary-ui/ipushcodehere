public with sharing class VolunteerAllocationController {

    @AuraEnabled
    public static List<VolunteerAllocationService.AssignVolunteersResponse> assignVolunteers(List<Id> eventIds) {
        return VolunteerAllocationService.assignVolunteers(eventIds);
    }
    
    @AuraEnabled
    public static Map<String, Boolean> checkPermissions() {
        return VolunteerAllocationService.checkPermissions();
    }
    @AuraEnabled
    public static string deleteAssignVolunteer(List<Id> eventIds, List<Id> studentIds) {
        return VolunteerAllocationService.deleteAssignVolunteer(eventIds, studentIds);
    }

    @AuraEnabled(cacheable = true)
    public static List<VolunteerAllocationService.VolunteerWorkload> getAllocatedVolunteers(Id eventId) {
        return VolunteerAllocationService.getAllocatedVolunteers(eventId);
    }

}