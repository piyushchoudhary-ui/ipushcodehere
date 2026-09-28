import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
//Arranged alphabetically
import assignVolunteers from "@salesforce/apex/VolunteerAllocationController.assignVolunteers";
import checkPermissions from "@salesforce/apex/VolunteerAllocationController.checkPermissions";
import deleteAssignVolunteer from "@salesforce/apex/VolunteerAllocationController.deleteAssignVolunteer";
import getAllocatedVolunteers from "@salesforce/apex/VolunteerAllocationController.getAllocatedVolunteers";
import generalInfoToAssign from "@salesforce/label/c.General_Info_To_Assign";
import noPermissionToAccessStudentCategory from "@salesforce/label/c.No_Permission_To_Access_Student_Category";
import noPermissionToAccessStudentName from "@salesforce/label/c.No_Permission_To_Access_Student_Name";
import noPermissionToAssignVolunteer from "@salesforce/label/c.No_Permission_To_Assign_Volunteer";
import noVolunteersAllocated from "@salesforce/label/c.No_Volunteers_Are_Allocated_Now";

const actions = [
    { label: 'Delete', name: 'delete' }
];
const columns = [
    { label: 'Volunteer Name', fieldName: 'studentName' },
    { label: 'Category', fieldName: 'category' },
    { label: 'Event Count Volunteer Assigned To', fieldName: 'totalCount' },
    { type: 'action', typeAttributes: { rowActions: actions }},
];

export default class VolunteerAllocator extends LightningElement {
    //arranged alphabetically
    assignVolunteerDetails;
    allocatedVolunteers;
    columns = columns;
    @api recordId;
    initialAccessMessage = null;
    isSuccess;
    permissionMessage = null;
    showModal = false;
    statusMessage;
    wiredAllocatedVolunteersResult;

    label = {
        noVolunteersAllocated,
        generalInfoToAssign
    };

    permissionLabels = {
        isHavingAssigningPermission: noPermissionToAssignVolunteer,
        isHavingStudentNamePermission: noPermissionToAccessStudentName,
        isHavingStudentCategoryPermission: noPermissionToAccessStudentCategory
    };

    get hasAllocatedVolunteers() {
        return this.allocatedVolunteers?.length > 0;
    }

    get hasPermissionMessage() {
        return this.permissionMessage != null;
    }

    get hasNoPermissionMessage() {
        return this.permissionMessage == '';
    }

    connectedCallback() {
        this.checkInitialPermissions();
    }

    @wire(getAllocatedVolunteers, { eventId: '$recordId' })
    wiredAllocatedVolunteers(result) {
        this.wiredAllocatedVolunteersResult = result;
        const { data, error } = result;

        if (data) {
            this.allocatedVolunteers = data.map(item => ({
                ...item,
                totalCount: item.classCount + item.branchCount + item.collageCount
            }));
        } else if (error) {
            console.error('Error loading volunteers:', error);
            this.allocatedVolunteers = [];
        }
    }

    checkInitialPermissions() {
        checkPermissions(
        ).then(response => {
            let deniedMessages = [];
            let permissionKeys = ['isHavingStudentNamePermission', 'isHavingStudentCategoryPermission'];
            for (let key of permissionKeys) {
                if (!response[key]) {
                    deniedMessages.push(this.permissionLabels[key]);
                }
            }
            this.initialAccessMessage = deniedMessages.join(' & ');
            refreshApex(this.wiredAllocatedVolunteersResult);

        })
        .catch(error => {
            console.error('error :' + error);
        });
    }
    
    handleAssignVolunteers() {
        checkPermissions(
        ).then(response => {
            let deniedMessages = [];
            for (let key in this.permissionLabels) {
                console.log('key ' + response[key]);
                if(!response[key]) {
                    deniedMessages.push(this.permissionLabels[key]);
                }
                console.log(deniedMessages);
            }
            this.permissionMessage = deniedMessages.join(" & ");
            this.showModal = true;
        }).catch(error => {
            console.error('error :' + error);
        })
    }

    handleAssign() {
        assignVolunteers({
            eventIds: [this.recordId]
        }).then(response => {
            const resp = response[0];
            this.statusMessage = resp.statusMessage;
            if (resp.isSuccess && resp.allocatedVolunteers) {
                refreshApex(this.wiredAllocatedVolunteersResult);
                this.showToast('Successful Allocation', this.statusMessage, 'success');
            } else {
                this.showToast('Failed Allocation', this.statusMessage, 'error');
            }
            this.showModal = false;
        }).catch(error => {
            console.error('Error from Apex:', error);
            this.statusMessage = error?.body?.message || 'An unexpected error occurred.';
            this.showModal = false;
            this.showToast('Failed Allocation', this.statusMessage, 'error');
        });
    }

    deleteVolunteer(event) {
        const { studentId } = event.detail.row;
        deleteAssignVolunteer({
            eventIds: [this.recordId],
            studentIds: [studentId] 
        }).then( response => {
            if(response === 'SUCCESS') {
                const updatedList = this.allocatedVolunteers.filter(item => item.studentId !== studentId);
                this.allocatedVolunteers = updatedList;
            }
        })
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    handleModalClose() {
        this.showModal = false;
    }
}