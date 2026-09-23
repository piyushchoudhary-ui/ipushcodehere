import { LightningElement, api } from 'lwc';
import assignVolunteers from "@salesforce/apex/VolunteerAllocationHandler.assignVolunteers";
import deleteAssignVolunteer from "@salesforce/apex/VolunteerAllocationHandler.deleteAssignVolunteer";
import getAllocatedVolunteers from "@salesforce/apex/VolunteerAllocationHandler.getAllocatedVolunteers";
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

    label = {
        noVolunteersAllocated
    };

    get hasAllocatedVolunteers() {
        return this.allocatedVolunteers?.length > 0;
    }

    connectedCallback() {
        this.loadAllocatedVolunteers(); //will populate at initial load
    }
    
    handleAssignVolunteers() {
        assignVolunteers({
            eventIds: [this.recordId]
        }).then(response => {
            const resp = response[0];
            this.statusMessage = resp.statusMessage;
            this.showModal = true;
            if (resp.isSuccess && resp.allocatedVolunteers) {
                this.loadAllocatedVolunteers(); //will populate after remaining volunteer assigned.
            }
        }).catch(error => {
            console.error('Error from Apex:', error);
            this.statusMessage = error?.body?.message || 'An unexpected error occurred.';
            this.showModal = true;
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

    handleModalClose() {
        this.showModal = false;
    }
}