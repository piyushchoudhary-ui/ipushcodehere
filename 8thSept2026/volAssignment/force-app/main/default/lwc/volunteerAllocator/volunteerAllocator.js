import { LightningElement, api } from 'lwc';
import assignVolunteers from "@salesforce/apex/VolunteerAllocationHandler.assignVolunteers";
import deleteAssignVolunteer from "@salesforce/apex/VolunteerAllocationHandler.deleteAssignVolunteer";

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

    connectedCallback() {
        console.log('Hello from ConnectedCallback');
    }
    
    handleAssignVolunteers() {
        assignVolunteers({
            eventIds: [this.recordId]
        }).then( response => {
            const resp = response[0];
            if(resp.isSuccess) {
                this.allocatedVolunteers = resp.allocatedVolunteers.map(item => ({
                    ...item,
                    totalCount: item.classCount + item.branchCount + item.collageCount
                }));
            }
        }).catch(error => {
            console.error('Error from Apex:', error);
            console.error('Error from Apex:', error.body.message);
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

}