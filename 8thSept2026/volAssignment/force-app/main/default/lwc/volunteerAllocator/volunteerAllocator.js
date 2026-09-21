import { LightningElement, api } from 'lwc';
import apexMethodName from "@salesforce/apex/VolunteerAllocationHandler.assignVolunteers";

export default class VolunteerAllocator extends LightningElement {
    @api recordId;

    connectedCallback() {
        console.log('Hello from ConnectedCallback');
    }
    
    handleAssignVolunteers() {
        apexMethodName({ 
            eventIds: [this.recordId] 
        }).then( response => {
            console.log('Response from Apex:', response);
        }).catch(error => {
            console.error('Error from Apex:', error);
        });
    }
}