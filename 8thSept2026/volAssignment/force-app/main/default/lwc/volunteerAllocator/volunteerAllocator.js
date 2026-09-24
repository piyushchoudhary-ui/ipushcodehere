import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import assignVolunteers from "@salesforce/apex/VolunteerAllocationHandler.assignVolunteers";
import deleteAssignVolunteer from "@salesforce/apex/VolunteerAllocationHandler.deleteAssignVolunteer";
import getAllocatedVolunteers from "@salesforce/apex/VolunteerAllocationHandler.getAllocatedVolunteers";
import generalInfoToAssign from "@salesforce/label/c.General_Info_To_Assign";
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
    @api recordId;
    columns = columns;
    assignVolunteerDetails;
    isSuccess;
    statusMessage;
    allocatedVolunteers;
    showModal = false;
    permissionMessage = null;

    label = {
        noVolunteersAllocated,
        generalInfoToAssign
    };

    get hasAllocatedVolunteers() {
        return this.allocatedVolunteers?.length > 0;
    }

    get hasPermissionMessage() {
        return this.permissoinMessage != null;
    }

    get hasNoPermissionMessage() {
        return this.permissoinMessage == null;
    }

    connectedCallback() {
        this.loadAllocatedVolunteers(); 
    }
    
    handleAssignVolunteers() {
        //checkPermissions
        this.showModal = true;
    }

    handleAssign() {
        assignVolunteers({
            eventIds: [this.recordId]
        }).then(response => {
            const resp = response[0];
            console.log('hello from resp :', resp);
            this.statusMessage = resp.statusMessage;
            if (resp.isSuccess && resp.allocatedVolunteers) {
                this.loadAllocatedVolunteers(); //will populate after remaining volunteer assigned.
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

    loadAllocatedVolunteers() {
        getAllocatedVolunteers({
            eventId: this.recordId
        }).then(response => {
            this.allocatedVolunteers = response.map(item => ({
                ...item,
                totalCount: item.classCount + item.branchCount + item.collageCount
            }));
        }).catch(error => {
            console.error('Error loading volunteers:', error);
            this.allocatedVolunteers = [];
        });
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