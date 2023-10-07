/**
 * @author            : salih.cendik
 * @last modified on  : 28-09-2023
 * @last modified by  : salih.cendik
**/
import { LightningElement, wire, api, track } from 'lwc';
import fetchPanelsByStandId from '@salesforce/apex/TR_StandController.fetchPanelsByStandId';
import searchProduct from '@salesforce/apex/TR_StandController.searchProduct';
import updatePanels from '@salesforce/apex/TR_StandController.updatePanels';
import getDivisionsByParentAccount from '@salesforce/apex/TR_StandController.fetchDivisionsByAccountId';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

//LABELS
import existingPanelCode from '@salesforce/label/c.trPanelForm_ExistingPanelCode';
import existingSerie from '@salesforce/label/c.trPanelForm_ExistingSerie';
import requestedPanelCode from '@salesforce/label/c.trPanelForm_RequestedPanelCode';
import header1 from '@salesforce/label/c.trPanelForm_Header1';
import header2 from '@salesforce/label/c.trPanelForm_Header2';
import btnSave from '@salesforce/label/c.trPanelForm_BtnSave';
import btnInApproval from '@salesforce/label/c.trPanelForm_ApprovalPending';
import msgSuccess from '@salesforce/label/c.trPanelForm_MsgSuccess';
export default class ChangePanelsForStand extends NavigationMixin(LightningElement) {
    showSpinner = false;
    disabledPanel = false;
    @track panels = [];
    @api recordId = 'a043L000004QmpZQAS';
    showSerieLayout = false;
    stand_StandCode;
    stand_StandStatus;
    accountDivisions = [];
    parentAccountId;
    label = {
        existingPanelCode,
        existingSerie,
        requestedPanelCode,
        header1,
        header2,
        btnSave,
        btnInApproval,
        msgSuccess
    }

    connectedCallback() {
        this.fetchPanels();
    }

    fetchPanels() {
        fetchPanelsByStandId({ standId: this.recordId })
            .then(result => {
                console.log('fetchPanels result: ', result);
                this.panels = this.generatePanels(result);
                if (this.panels) {
                    this.getDivisionsForParentAccount();
                }
            })
            .catch(error => {
                console.log('fetchPanels error: ', error);
            });
    }
    getDivisionsForParentAccount() {
        getDivisionsByParentAccount({ parentAccountId: this.parentAccountId })
            .then(result => {
                this.accountDivisions = result;
            })
            .catch(error => {
                console.log('getDivisionsForParentAccount() Error:', error);
            });
    }

    generatePanels(panelData) {

        if (panelData) {
            const panel = panelData[0];
            this.parentAccountId = panel.AccountDisplay__r.Account__c;
            this.stand_StandStatus = panel.AccountDisplay__r.Stand_Status__c;
            this.stand_StandCode = panel.AccountDisplay__r.Stand_Code__r.Stand_Code__c;
            const stand_Status = panel.AccountDisplay__r.Status__c;
            this.showSerieLayout = this.stand_StandStatus == 'Existing Stand';

            if (stand_Status == 'Waiting for Approval' || stand_Status == 'Awaiting Change Request Approval') {
                this.disabledPanel = true;
            }
        }

        const generatedPanels = [];
        for (let index = 0; index < panelData.length; index++) {
            const panel = panelData[index];
            const generatedPanel = {
                index: panel.Panel_No__c,
                id: panel.Id,
                lineName: panel.Name,
                existingProdId: panel.Product__c,
                existingProdName: (panel.Product__r || {}).Name,
                existingSerieName: (panel.Serie__r || {}).Name
            }

            if (panel.Requested_Product__c) {
                generatedPanel.icon = 'standard:product';
                generatedPanel.requestedProdId = panel.Requested_Product__c;
                generatedPanel.requestedProdName = panel.Requested_Product__r.Name;
            }
            generatedPanels.push(generatedPanel);
        }
        return generatedPanels;
    }
    async handlePanelSearch(searchTerm) {
        try {
            return await searchProduct({ searchTerm, filter: this.inputAdditionalCriteria });
        } catch (e) {
            console.log(e.body.message);
        }
    }

    //following this inputAdditionalCriteria:
    get panelCodeSearchFilter() {
        const filter = {
            type: 'panelCode',
            standCode: this.stand_StandCode,
            standStatus: this.stand_StandStatus,
            accountDivisions: this.accountDivisions
        };
        return JSON.parse(JSON.stringify(filter));
    }
    handlePanelSelect(event) {
        const { recordId, index, label, productCode } = event.detail;
        this.updatePanelByIndex(index, 'requestedProdId', recordId);
    }

    handleSave() {
        console.log('panels: ', this.panels);
        if (this.panels.length == 0) {
            this.showToast('Error', 'No Panel', 'error');
            return;
        }

        const accountDisplayProducts = this.mappingAccountDisplayProduct(this.panels);
        console.log('accountDisplayProducts: ', accountDisplayProducts);

        this.showSpinner = true;
        updatePanels({ panels: JSON.stringify(accountDisplayProducts) })
            .then(result => {
                this.showSpinner = false;
                this.showToast('Successfully', this.label.msgSuccess, 'success');
            })
            .catch(error => {
                console.log('handleSave-error ', error);
                this.showToast('Error', error.body.message, 'error');
            }).finally(() => {
                this.showSpinner = false;
            });
    }

    mappingAccountDisplayProduct(panelData) {
        let accountDisplayProducts = [];
        for (let i = 0; i < panelData.length; i++) {
            let panel = panelData[i];
            if (!panel.requestedProdId) {
                continue;
            }
            let accountDisplayProduct = { Id: panel.id, Requested_Product__c: panel.requestedProdId };
            accountDisplayProducts.push(accountDisplayProduct);
        }
        return accountDisplayProducts;
    }

    updatePanelByIndex(index, key, value) {
        const newPanels = this.panels.filter(() => true);
        const thisPanel = newPanels.filter(c => c.index == index)[0] || {};
        thisPanel[key] = value;
        this.panels = newPanels;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    get setReadonlyStyleForPanel() {
        if (this.disabledPanel) {
            return 'pointer-events:none';
        }
        return 'pointer-events:auto';
    }

    get labelBtnSave() {
        if (this.disabledPanel) {
            return this.label.btnInApproval;
        }
        return this.label.btnSave;
    }
}