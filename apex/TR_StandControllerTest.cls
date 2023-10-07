/**
 * @author            : salih.cendik
 * @last modified on  : 01-10-2023
 * @last modified by  : salih.cendik
**/
@isTest
public with sharing class TR_StandControllerTest {
    @testSetup
    private static void testSetup() {
        Definition2__c state = new Definition2__c(
            RecordTypeId = Schema.sObjectType.Definition2__c.getRecordTypeInfosByDeveloperName().get('State').getRecordTypeId(),
            Name = 'Test State',
            Country__c = 'TR');
        insert state;
        
        Definition2__c district = new Definition2__c(
            RecordTypeId =  Schema.sObjectType.Definition2__c.getRecordTypeInfosByDeveloperName().get('District').getRecordTypeId(),
            Name = 'Test Disrict',
            State__c= state.Id);
        insert district;
        
        Account parentAccount = new Account(
            RecordTypeId = Schema.sObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer_TR').getRecordTypeId(),
            Name = 'Test Account',
            Country__c = 'TR',
            State__c = state.Id,
            District__c = district.Id,
            TaxNumber__c = '0123456789',
            SAPNumber__c = 'SapNumber',
            Status__c = 'Active',
            Company__c = '2100');
        insert parentAccount;

        Account_Sales_Org__c accountSalesOrg = new Account_Sales_Org__c(
        RecordTypeId = Schema.sObjectType.Account_Sales_Org__c.getRecordTypeInfosByDeveloperName().get('TR_Sales_Org').getRecordTypeId(),
        Account__c = parentAccount.Id,
        SalesOrg__c = '2101',
        DistributionChannel__c = '20',
        Division__c = '10', 
        CustomerPricingPresedure__c = '1',
        CompanyPicklist__c = '2100',
        Tax_Class__c = '0',
        Customer_Segment__c = 'A',
        Responsible__c = UserInfo.getUserId());
        insert accountSalesOrg;

        Account shop = new Account(
            RecordTypeId = Schema.sObjectType.Account.getRecordTypeInfosByDeveloperName().get('TR_Project').getRecordTypeId(),
            ParentId = parentAccount.Id,
            Name = 'Test Shop',
            Country__c = 'TR',
            State__c = state.Id,
            District__c = district.Id,
            TaxNumber__c = '0123456789',
            SAPNumber__c = 'SapNumber',
            Status__c = 'Active',
            Company__c = '2100');
        insert shop;

        Product2 product = new Product2(
            Name = 'Test',
            ProductCode = 'KMZ9170000',
            BaseUnitOfMeasure__c = 'CS',
            IsActive = true,
            MaterialType__c = 'KARO',
            Company__c = '2100');
        insert product;

        Product2 productAsStand = createProductAndSalesOrg('Test Diğer - Stant', 'Active Stand', 'Diğer', '10');
        Product2 productAsTRPanel = createProductAndSalesOrg('Test TR Panel', 'Active Panel', 'D09', '10');
        Product2 productByHierarchy = createProductAndSalesOrg('Test Hierarchy Panel', 'Active Panel', 'D19', '10');
        
        Account_Display__c accountDisplay = new Account_Display__c(
            Name = 'Test tr account display',
            RecordTypeId = Schema.sObjectType.Account_Display__c.getRecordTypeInfosByDeveloperName().get('TR_Account_Display').getRecordTypeId(),
            Account__c = parentAccount.Id,
            Shop__c = shop.Id,
            Stand_Code__c = productAsStand.Id,
            Status__c = 'Passive');
        insert accountDisplay;
        
        Account_Display_Product__c accountDisplayProduct = new Account_Display_Product__c(
            RecordTypeId = Schema.sObjectType.Account_Display_Product__c.getRecordTypeInfosByDeveloperName().get('TR_Account_Display_Product').getRecordTypeId(),
            AccountDisplay__c = accountDisplay.Id,
            Panel_No__c = 1,
            Product__c = product.Id);
        insert accountDisplayProduct;

        Definition2__c productSerieDefinition = new Definition2__c(
            RecordTypeId = Schema.sObjectType.Definition2__c.getRecordTypeInfosByDeveloperName().get('Product_Serie').getRecordTypeId(),
            Name = 'KAFKA',
            SAPCode__c = '2100_KFK',
            Company__c = '2100');
        insert productSerieDefinition;
    }

    private static Product2 createProductAndSalesOrg(String name, String activeStandPanel, String standCode, String division) {
        Product2 product = new Product2(
            Name = name,
            IsActive = true,
            Company__c = '2100',
            Stand_Code__c = standCode,
            ProductHierarchy__c =  '1004001012',
            Active_Stand_Panel__c = activeStandPanel
        );
        insert product;

        Product_Sales_Org__c productSD = new Product_Sales_Org__c(
            RecordTypeId =  Schema.sObjectType.Product_Sales_Org__c.getRecordTypeInfosByDeveloperName().get('Product_Sales_Org_TR').getRecordTypeId(),
            Product__c = product.Id,
            Division__c = division);
        insert productSD;

        return product;
    }

    @isTest
    private static void testFetchPanelsByStandId() {
        Account_Display__c stand = [SELECT Id FROM Account_Display__c LIMIT 1];
        List<Account_Display_Product__c> accountDisplayProducts = TR_StandController.fetchPanelsByStandId(stand.Id);
        System.assert(accountDisplayProducts.size()>0);
    }

    @isTest
    private static void testFetchDivisionsByAccountId() {
        Account parentAccount = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Dealer_TR' LIMIT 1];
        List<String> divisions = TR_StandController.fetchDivisionsByAccountId(parentAccount.Id);
        System.assert(divisions.size()>0);
    }

    @isTest
    private static void testSearchShop() {
        Account parentAccount = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Dealer_TR' LIMIT 1];
        List<TR_StandController.LookUpSearchModel> searchModels = TR_StandController.searchShop('Test Shop', parentAccount.Id);
        System.assert(searchModels.size()>0);
    }

    @isTest
    private static void testGetStandsForNewStand() {
        TR_StandController.SearchInitialFilter filter = new TR_StandController.SearchInitialFilter();
        filter.type = 'standCode';
        filter.standStatus = 'New Stand'; 
        filter.accountDivisions = new List<String>{'10'};
        List<TR_StandController.LookUpSearchModel> searchModels = TR_StandController.searchProduct('Test', filter);
        System.assert(searchModels.size()>0);
    }

    @isTest
    private static void testGetStandsForExistingStand() {
        TR_StandController.SearchInitialFilter filter = new TR_StandController.SearchInitialFilter();
        filter.type = 'standCode';
        filter.standStatus = 'Existing Stand'; 
        filter.accountDivisions = new List<String>{'10'};
        List<TR_StandController.LookUpSearchModel> searchModels = TR_StandController.searchProduct('Test', filter);
        System.assert(searchModels.size()>0);
    }
    
    @isTest
    private static void testGetTRPanels() {
        TR_StandController.SearchInitialFilter filter = new TR_StandController.SearchInitialFilter();
        filter.type = 'panelCode';
        filter.standStatus = 'New Stand'; 
        filter.standCode = 'D09'; 
        filter.accountDivisions = new List<String>{'10'};
        List<TR_StandController.LookUpSearchModel> searchModels = TR_StandController.searchProduct('Test', filter);
        System.assert(searchModels.size()>0);
    }

    @isTest
    private static void testGetActivePanels() {
        TR_StandController.SearchInitialFilter filter = new TR_StandController.SearchInitialFilter();
        filter.type = 'panelCode';
        filter.standStatus = 'New Stand'; 
        filter.accountDivisions = new List<String>{'10'};
        List<TR_StandController.LookUpSearchModel> searchModels = TR_StandController.searchProduct('Test', filter);
        System.assert(searchModels.size()>0);
    }
    
    @isTest
    private static void testGetPanelsByHierarchy() {
        TR_StandController.SearchInitialFilter filter = new TR_StandController.SearchInitialFilter();
        filter.type = 'panelCode';
        filter.standStatus = 'New Stand'; 
        filter.standCode = 'D19'; 
        filter.accountDivisions = new List<String>{'10'};
        List<TR_StandController.LookUpSearchModel> searchModels = TR_StandController.searchProduct('Test', filter);
        System.assert(searchModels.size()>0);
    }

    @isTest
    private static void testSearchSerie() {
        List<TR_StandController.LookUpSearchModel> searchModels = TR_StandController.searchSerie('KAFKA');
        System.assert(searchModels.size()>0);
    }

    @isTest
    private static void testInsertStand() {
        Account shop = [SELECT Id, ParentId FROM Account WHERE Name = 'Test Shop' LIMIT 1];
        Product2 standCode = [SELECT Id FROM Product2 WHERE Name = 'Test Diğer - Stant' LIMIT 1];
        Product2 panelCode = [SELECT Id FROM Product2 WHERE Name = 'Test TR Panel' LIMIT 1];
        
        Account_Display__c newAccDisplay = new Account_Display__c(
        Shop__c = shop.Id,
        Stand_Status__c = 'Existing Stand',
        Stand_Code__c = standCode.Id);

        TR_StandController.Stand stand = new TR_StandController.Stand();
        stand.accountDisplay = newAccDisplay;
        stand.fileName = 'test.jpg';
        stand.fileContent = EncodingUtil.base64Encode(Blob.valueOf('Test content'));

        Account_Display_Product__c accountDisplayProduct = new Account_Display_Product__c(
        Panel_No__c = 1,
        Status__c = 'Active',
        Product__c = panelCode.Id);

        TR_StandController.Panel panel = new TR_StandController.Panel();
        panel.accountDisplayProduct = accountDisplayProduct;
        panel.fileName = 'test.jpg';
        panel.fileContent = EncodingUtil.base64Encode(Blob.valueOf('Test content'));
        List<TR_StandController.Panel> panels = new List<TR_StandController.Panel>{panel};

        String standToStr = JSON.serialize(stand, true);
        String panelsToStr = JSON.serialize(panels, true);
        String recordId = TR_StandController.insertStand(standToStr, panelsToStr, shop.ParentId);
        System.assert([SELECT Id FROM Account_Display__c WHERE Id = :recordId].size()>0);
    }

    @isTest
    private static void testUpdatePanels() {
        List<Account_Display_Product__c> accDisplayProds = [SELECT Id FROM Account_Display_Product__c];
        accDisplayProds[0].Panel_No__c = 2;
        String panelToStr = JSON.serialize(accDisplayProds, true);
        TR_StandController.updatePanels(panelToStr);
        System.assert([SELECT Panel_No__c FROM Account_Display_Product__c][0].Panel_No__c == 2);
    }

    @isTest
    private static void testGetUserById() {
        User user = TR_StandController.getUserById();
        System.assert(user != null);
    }
}