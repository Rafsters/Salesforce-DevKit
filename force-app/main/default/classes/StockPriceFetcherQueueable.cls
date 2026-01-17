public with sharing class StockPriceFetcherQueueable implements Queueable, Database.AllowsCallouts {
    public StockPriceFetcherQueueable() {
    }

    public void execute(QueueableContext qc) {
        String apiToken = fetchAPITokenFromCustomSettings();
        List<Stock__c> stocks = [SELECT Id, Ticker__c FROM Stock__c LIMIT 20];
        Map<String, Stock__c> tickerToStockMap = new Map<String, Stock__c>();
        for (Stock__c stock : stocks) {
            tickerToStockMap.put(stock.Ticker__c, stock);
        }
        List<Stock_Price__c> stockPrices = new List<Stock_Price__c>();
        List<Stock_Price__c> stockPricesToUpdate = new List<Stock_Price__c>();
        List<ErrorLog__c> errorLogs = new List<ErrorLog__c>();
        for (String stockTicker : tickerToStockMap.keySet()) {
            if (calloutLimitsExceeded()) {
                break;
            }
            HttpRequest req = new HttpRequest();
            // Free API does not support bulk requests
            // Free API limit: max 20 daily callouts, requires single-stock requests in a loop
            req.setEndpoint('callout:EODHD/' + stockTicker + '?filter=last_close&api_token=' + apiToken + '&fmt=json');
            req.setMethod('GET');
            Http http = new Http();
            try {
                HTTPResponse res = http.send(req);
                if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                    String responsePrice = res.getBody();
                    if (responsePrice != null && tickerToStockMap.containsKey(stockTicker)) {
                        try {
                            Decimal price = Decimal.valueOf(responsePrice);
                            stockPrices.add(
                                StockPriceService.createNewStockPrice(price, tickerToStockMap.get(stockTicker).Id)
                            );
                        } catch (Exception e) {
                            errorLogs.add(ErrorLogService.createErrorLogWithMessage('Error parsing data'));
                        }
                    }
                }
            } catch (CalloutException ce) {
                errorLogs.add(ErrorLogService.createErrorLogWithMessage(ce.getStackTraceString()));
            }
        }
        SavePoint sp = Database.setSavepoint();
        try {
            if (!stockPrices.isEmpty()) {
                StockPriceService.updateIsLatestFieldForOldStockPrices(stockPricesToUpdate);
                if (!stockPricesToUpdate.isEmpty()) {
                    update stockPricesToUpdate;
                }
                insert stockPrices;
            }
        } catch (Exception e) {
            Database.rollback(sp);
            errorLogs.add(ErrorLogService.createErrorLogWithMessage(e.getStackTraceString()));
        } finally {
            if (!errorLogs.isEmpty()) {
                insert errorLogs;
            }
        }
    }

    private Boolean calloutLimitsExceeded() {
        return Limits.getCallouts() >= Limits.getLimitCallouts();
    }

    private String fetchAPITokenFromCustomSettings() {
        return [SELECT Api_Token__c FROM EODHD_API_Token__c LIMIT 1].Api_Token__c;
    }
}
