/**
 * @author            : salihcendik
 * @last modified on  : 30-09-2023
 * @last modified by  : salih.cendik
**/
public with sharing class TR_StandController {
    @AuraEnabled
    public static List<Account_Display_Product__c> fetchPanelsByStandId(String standId) {
        return [SELECT Id, Name, Product__c, Product__r.Name, Requested_Product__c, Requested_Product__r.Name, Serie__c, Serie__r.Name, AccountDisplay__r.Account__c, AccountDisplay__r.Status__c, AccountDisplay__r.Stand_Status__c, AccountDisplay__r.Stand_Code__r.Stand_Code__c, Panel_No__c
        FROM Account_Display_Product__c 
        WHERE AccountDisplay__c = :standId ORDER BY Name ASC];
    }

    @AuraEnabled
    public static List<String> fetchDivisionsByAccountId(String parentAccountId) {
        List<string> divisions = new List<String>();
        List<AggregateResult > results = [SELECT Division__c, COUNT(id) FROM Account_Sales_Org__c WHERE Account__c = :parentAccountId GROUP BY Division__c];
        for(AggregateResult result: results){
            divisions.add((String) result.get('Division__c'));
        }
        return divisions;
    }

    @AuraEnabled
    public static List<LookUpSearchModel> searchShop(String searchTerm, String parentAccountId){
        parentAccountId = determineAccount(parentAccountId);
        try {
            String searchLike;
            if(searchTerm.contains('%')) {
                searchLike = searchTerm;
            } else {
                searchLike = '%' + searchTerm + '%';
            }

            List<Account> accounts = [SELECT Id, Name FROM Account WHERE ParentId = :parentAccountId AND RecordType.DeveloperName = 'TR_Project' AND Name LIKE :searchLike];
            if(accounts.isEmpty()) {
                throw new DmlException('No Shop!');
            }

            List<LookUpSearchModel> results = new List<LookUpSearchModel>();
            for (Account account : accounts) {
                LookUpSearchModel result = new LookUpSearchModel();
                result.recordId = account.Id;
                result.label = account.Name;
                result.icon = 'standard:account';
                results.add(result);
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<LookUpSearchModel> searchProduct(String searchTerm, SearchInitialFilter filter){
        try {
            System.debug('filter:'+filter);
            String searchLike;
            if(searchTerm.contains('%')) {
                searchLike = searchTerm;
            } else {
                searchLike = '%' + searchTerm + '%';
            }

            List<Product2> products = getProducts(searchLike, filter);
            if(products.isEmpty()) {
                throw new DmlException('No '+ filter.type);
            }

            List<LookUpSearchModel> results = new List<LookUpSearchModel>();
            for (Product2 product : products) {
                LookUpSearchModel result = new LookUpSearchModel();
                result.recordId = product.Id;
                result.label = product.Name;
                result.secondaryLabel = product.ProductCode;
                result.standCode = product.Stand_Code__c;
                result.icon = 'standard:product';
                results.add(result);
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static List<Product2> getProducts(String searchLike, SearchInitialFilter filter) {
        String type = filter.type;
        String standStatus = filter.standStatus;
        String standCode = filter.standCode;
        List<String> accountDivisions = filter.accountDivisions;
        
        List<Product2> products = new List<Product2>();
        if (type == 'standCode') {
            if (standStatus == 'New Stand') {
                products = getStandsForNewStand(searchLike, accountDivisions);
            }else if (standStatus == 'Existing Stand'){
                products = getStandsForExistingStand(searchLike, accountDivisions);
            }
        }
        else if (type == 'panelCode'){
            if (standCode == 'D09' || standCode == 'D10') {
                products = getTRPanels(searchLike, accountDivisions);
            }else if(standCode == 'D19' || standCode == 'D21'){
                products = getPanelsByHierarchy(searchLike, accountDivisions);
            }
            else{
                products = getActivePanels(searchLike, accountDivisions);
            }
        }
        return products;
    }
    
    public static List<Product2> getActivePanels(String searchLike, List<String> accountDivisions){
        return [SELECT Id, Name, ProductCode, Stand_Code__c 
                FROM Product2 
                WHERE (ProductCode LIKE :searchLike OR Name LIKE :searchLike) AND 
                Active_Stand_Panel__c = 'Active Panel' AND
                Id IN (SELECT Product__c FROM Product_Sales_Org__c WHERE Division__c IN :accountDivisions)];
    }

    public static List<Product2> getTRPanels(String searchLike, List<String> accountDivisions){
            return [SELECT Id, Name, ProductCode, Stand_Code__c 
                    FROM Product2 
                    WHERE (ProductCode LIKE :searchLike OR Name LIKE :searchLike) AND 
                    Company__c = '2100' AND
                    Id IN (SELECT Product__c FROM Product_Sales_Org__c WHERE Division__c IN :accountDivisions) LIMIT 50000];
    }

    public static List<Product2> getPanelsByHierarchy(String searchLike, List<String> accountDivisions){ 
        List<String> hierarchies = new List<String>{'1004001012', '2004001012'};
        return [SELECT Id, Name, ProductCode, Stand_Code__c
                FROM Product2 
                WHERE (ProductCode LIKE :searchLike OR Name LIKE :searchLike) AND 
                ProductHierarchy__c IN :hierarchies AND
                Id IN (SELECT Product__c FROM Product_Sales_Org__c WHERE Division__c IN :accountDivisions) LIMIT 50000];
    }

    public static List<Product2> getStandsForNewStand(String searchLike, List<String> accountDivisions){
        return [SELECT Id, Name, ProductCode, Stand_Code__c
                FROM Product2 
                WHERE (ProductCode LIKE :searchLike OR Name LIKE :searchLike) AND 
                Active_Stand_Panel__c = 'Active Stand' AND
                Stand_Code__c NOT IN (null, 'Diğer - Panelli', 'Diğer - Panelsiz') AND
                Id IN (SELECT Product__c FROM Product_Sales_Org__c WHERE Division__c IN :accountDivisions)];
    }

    public static List<Product2> getStandsForExistingStand(String searchLike, List<String> accountDivisions){
        return [SELECT Id, Name, ProductCode, Stand_Code__c
                FROM Product2 
                WHERE (ProductCode LIKE :searchLike OR Name LIKE :searchLike) AND 
                Stand_Code__c != null AND
                Id IN (SELECT Product__c FROM Product_Sales_Org__c WHERE Division__c IN :accountDivisions)];
    }

    @AuraEnabled
    public static List<LookUpSearchModel> searchSerie(String searchTerm){
        try {
            String searchLike;
            if(searchTerm.contains('%')) {
                searchLike = searchTerm;
            } else {
                searchLike = '%' + searchTerm + '%';
            }

            List<Definition2__c> definations = [SELECT Id, Name, SAPCode__c FROM Definition2__c 
            WHERE Name LIKE :searchLike AND Company__c = '2100' AND RecordType.DeveloperName = 'Product_Serie'];
            
            if(definations.isEmpty()) {
                throw new DmlException('No Serie Code!');
            }

            List<LookUpSearchModel> results = new List<LookUpSearchModel>();
            for (Definition2__c defination : definations) {
                LookUpSearchModel result = new LookUpSearchModel();
                result.recordId = defination.Id;
                result.label = defination.Name;
                result.secondaryLabel = defination.SAPCode__c;
                result.icon = 'standard:products';
                results.add(result);
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String insertStand(String stand, String panels, String accountId) {
        System.Savepoint sp = Database.setSavepoint();
        try {
            Stand standObj = (Stand) System.JSON.deserialize(stand, Stand.class);
            List<Panel> panelObjList = (List<Panel>) System.JSON.deserialize(panels, List<Panel>.class);
            
            System.debug('standObj ::: '+ standObj);
            System.debug('panelObjList ::: '+ panelObjList);

            String accountDisplayId = createAccountDisplay(accountId, standObj);
            createAccountDisplayProducts(accountDisplayId, panelObjList);
            return accountDisplayId;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    } 

    @AuraEnabled
    public static void updatePanels(String panels) {
        List<Account_Display_Product__c> panelObjList = (List<Account_Display_Product__c>) System.JSON.deserialize(panels, List<Account_Display_Product__c>.class);
        try {
            update panelObjList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static String createAccountDisplay(String accountId, Stand standObj) {
        String standRecTypeId = 
        Schema.sObjectType.Account_Display__c.getRecordTypeInfosByDeveloperName().get('TR_Account_Stand').getRecordTypeId();
        String relatedAccountId = determineAccount(accountId);
        Account_Display__c accountDisplay = standObj.accountDisplay;
        accountDisplay.Account__c = relatedAccountId;
        accountDisplay.RecordTypeId = standRecTypeId;
        insert accountDisplay;

        if (String.isNotBlank(standObj.fileName)) {
            insert attachFile(accountDisplay.Id, standObj.fileName, standObj.fileContent); 
        }
        return accountDisplay.Id;
    }

    public static void createAccountDisplayProducts(String accountDisplayId, List<Panel> panelObjList) {
        String panelRecTypeId = 
        Schema.sObjectType.Account_Display_Product__c.getRecordTypeInfosByDeveloperName().get('TR_Panel').getRecordTypeId();
        List<Account_Display_Product__c> accountDisplayProdsToInsert = new List<Account_Display_Product__c>();
        for (Panel panel : panelObjList) {
            panel.accountDisplayProduct.RecordTypeId = panelRecTypeId;
            panel.accountDisplayProduct.AccountDisplay__c = accountDisplayId;
            accountDisplayProdsToInsert.add(panel.accountDisplayProduct);
        }
        insert accountDisplayProdsToInsert;

        List<Attachment> filesToInsert = new List<Attachment>();
        for (Integer i = 0; i < panelObjList.size(); i++) {
            Panel panel = panelObjList[i];
            if (String.isNotBlank(panel.fileName)) {
                String parentId = accountDisplayProdsToInsert.get(i).Id;
                filesToInsert.add(attachFile(parentId, panel.fileName, panel.FileContent));
            }
        }
        insert filesToInsert;
    }

    public static String determineAccount(String recordId) {
        if (String.isBlank(recordId)) {
            return getUserById().Contact.AccountId;
        }else {
            return recordId;
        }
    }

    public static Attachment attachFile(String relatedId, String fileName, String fileData){
        Attachment attachment = new Attachment();
        attachment.Body = EncodingUtil.base64Decode(fileData); 
        attachment.Name = fileName;
        attachment.ParentId = relatedId; 
        return attachment;
    }

    public static User getUserById(){
        return [SELECT Id, Company__c, Contact.AccountId, Contact.Account.OwnerId, Contact.Account.SAPNumber__c,
        ContactId, Sales_Org__c, Account.Sales_Org__c, User.AccountId, Profile.Name  
        FROM User WHERE Id = :userinfo.getuserid()];
    }
   
    public class Stand {
        @AuraEnabled
        public Account_Display__c accountDisplay { get; set;}
        @AuraEnabled
        public String fileName { get; set;}
        @AuraEnabled
        public String fileContent { get; set;}
    }

    public class Panel {
        @AuraEnabled
        public Account_Display_Product__c accountDisplayProduct { get; set;}
        @AuraEnabled
        public String fileName { get; set;}
        @AuraEnabled
        public String fileContent { get; set;}
    }

    public class LookUpSearchModel {
        @AuraEnabled
        public String recordId { get; set;}       
        @AuraEnabled
        public String label { get; set;}     
        @AuraEnabled
        public String secondaryLabel { get; set; }
        @AuraEnabled
        public String baseUnitOfProduct { get; set; }
        @AuraEnabled
        public String standCode { get; set; }
        @AuraEnabled
        public String icon { get; set; }
        @AuraEnabled
        public String image { get; set; }
    }

    public class SearchInitialFilter{
        @AuraEnabled
        public String type {get;set;}
        @AuraEnabled
        public String standStatus {get;set;}
        @AuraEnabled
        public String standCode {get;set;}
        @AuraEnabled
        public List<String> accountDivisions {get;set;}
    }
}