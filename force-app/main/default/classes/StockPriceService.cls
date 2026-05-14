public with sharing class StockPriceService {
    public StockPriceService() {
    }

    public static Stock_Price__c createNewStockPrice(Decimal price, ID stockId) {
        Stock_Price__c stockPrice = new Stock_Price__c();
        stockPrice.Price__c = price;
        stockPrice.Stock__c = stockId;
        stockPrice.Close_Date__c = Date.today();
        stockPrice.IsLatestPrice__c = true;
        return stockPrice;
    }

    public static void updateIsLatestFieldForOldStockPrices(List<Stock_Price__c> stockPricesToUpdate) {
        List<Stock_Price__c> previousStockPrices = [
            SELECT IsLatestPrice__c
            FROM Stock_Price__c
            WHERE IsLatestPrice__c = TRUE
        ];
        System.debug('Test4');
        for (Stock_Price__c stockPrice : previousStockPrices) {
            stockPrice.IsLatestPrice__c = false;
            stockPricesToUpdate.add(stockPrice);
        }
    }
}
