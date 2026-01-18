@RestResource(urlMapping='/v1/stocks/*')
global with sharing class StockApi {
    private static final Map<String, String> stockFieldMap = new Map<String, String>{
        'ticker' => 'Ticker__c',
        'name' => 'Name',
        'industry' => 'Industry__c'
    };

    @HttpGet
    global static void handleGet() {
        RestRequest req = RestContext.request;
        RestResponse resp = RestContext.response;
        String uri = req.requestURI;
        resp.addHeader('Content-Type', 'application/json');

        if (req.params.containsKey('ticker')) {
            String ticker = req.params.get('ticker');
            if (!isValidTicker(ticker)) {
                resp.statusCode = 400;
                resp.responseBody = Blob.valueOf(JSON.serialize(new List<StockPriceDTO>()));
                return;
            }
            StockPriceDTO stockPrice = new StockPriceDTO();
            stockPrice = getStockPrice(req.params.get('ticker'));
            if (stockPrice == null) {
                resp.statusCode = 404;
                resp.responseBody = Blob.valueOf(JSON.serialize(stockPrice));
                return;
            }
            resp.statusCode = 200;
            resp.responseBody = Blob.valueOf(JSON.serialize(stockPrice));
        } else {
            resp.statusCode = 200;
            resp.responseBody = Blob.valueOf(JSON.serialize(getAllStockPrices()));
        }
    }

    @HttpPost
    global static void createStock() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        RestRequest req = RestContext.request;
        String reqBody = req.requestBody.toString();
        StockWrapper stockWrapper = StockWrapper.parse(reqBody);
        if (stockWrapper.name == null || stockWrapper.ticker == null) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(
                    new StockApiResponse('Stock name and stock ticker are required', 'REQUIRED_DATA_MISSING')
                )
            );
            return;
        }
        if (!isValidTicker(stockWrapper.ticker)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(
                    new StockApiResponse('Stock ticker is invalid. Please user format XXX.WAR', 'INVALID_TICKER')
                )
            );
            return;
        }
        Stock__c newStock = new Stock__c(
            Name = stockWrapper.name,
            Ticker__c = stockWrapper.ticker,
            Industry__c = stockWrapper.industry
        );
        try {
            insert newStock;
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new StockApiResponse('Created')));
        } catch (DMLException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new StockApiResponse('Stock already exists', 'STOCK_ALREADY_EXIST'))
            );
        }
    }

    @HttpPut
    global static void updateStock() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String body = RestContext.request.requestBody.toString();
        StockWrapper stockWrapper = StockWrapper.parse(body);

        if (stockWrapper.ticker == null || !isValidTicker(stockWrapper.ticker)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(
                    new StockApiResponse('Stock ticker is invalid. Please user format XXX.WAR', 'INVALID_TICKER')
                )
            );
            return;
        }
        List<Stock__c> stocks = [
            SELECT Id, Name, Ticker__c, Industry__c
            FROM Stock__c
            WHERE Ticker__c = :stockWrapper.ticker
            LIMIT 1
        ];

        if (stocks.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new StockApiResponse('Stock not found', 'NOT_FOUND')));
            return;
        }
        Stock__c stockToUpdate = stocks[0];
        stockToUpdate.Ticker__c = stockWrapper.ticker;
        stockToUpdate.Industry__c = stockWrapper.industry;
        stockToUpdate.Name = stockWrapper.name;

        try {
            update stockToUpdate;
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new StockApiResponse('Updated')));
        } catch (DmlException e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new StockApiResponse('Error updating Stock', 'UPDATE_FAILED'))
            );
        }
    }

    @HttpPatch
    global static void updateStockFields() {
        RestRequest request = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String body = RestContext.request.requestBody.toString();
        StockWrapper stockWrapper = StockWrapper.parse(body);
        if (stockWrapper.ticker == null) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new StockApiResponse('Stock ticker is required', 'TICKER_MISSING'))
            );
            return;
        }
        List<Stock__c> stocks = [
            SELECT Id, Name, Ticker__c, Industry__c
            FROM Stock__c
            WHERE Ticker__c = :stockWrapper.ticker
            LIMIT 1
        ];
        if (stocks.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new StockApiResponse('Stock ticker does not exist', 'NOT_FOUND'))
            );
            return;
        }
        Stock__c stockToUpdate = stocks[0];
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(request.requestbody.tostring());
        for (String fieldName : params.keySet()) {
            if (!stockFieldMap.containsKey(fieldName)) {
                continue;
            }
            stockToUpdate.put(stockFieldMap.get(fieldName), params.get(fieldName));
        }
        try {
            update stockToUpdate;
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new StockApiResponse('Updated')));
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new StockApiResponse('Updated failed', 'UPDATE_FAILED')));
        }
    }

    private static List<StockPriceDTO> getAllStockPrices() {
        Date todayDate = Date.today();

        List<Stock_Price__c> prices = [
            SELECT Stock__r.Name, Stock__r.Ticker__c, Price__c
            FROM Stock_Price__c
            WHERE IsLatestPrice__c = TRUE
        ];

        List<StockPriceDTO> response = new List<StockPriceDTO>();
        for (Stock_Price__c sp : prices) {
            response.add(new StockPriceDTO(sp.Stock__r.Name, sp.Stock__r.Ticker__c, sp.Price__c));
        }
        return response;
    }

    private static StockPriceDTO getStockPrice(String stockTicker) {
        List<Stock_Price__c> stockPrice = [
            SELECT Stock__r.Name, Stock__r.Ticker__c, Price__c
            FROM Stock_Price__c
            WHERE IsLatestPrice__c = TRUE AND Stock__r.Ticker__c = :stockTicker
            LIMIT 1
        ];

        if (!stockPrice.isEmpty()) {
            StockPriceDTO response = new StockPriceDTO();
            response.name = stockPrice[0].Stock__r.Name;
            response.price = stockPrice[0].Price__c;
            response.ticker = stockPrice[0].Stock__r.Ticker__c;
            return response;
        }

        return null;
    }

    private static Boolean isValidTicker(String ticker) {
        if (String.isBlank(ticker)) {
            return false;
        }
        return Pattern.matches('^[A-Z]{3}\\.[A-Z]{3}$', ticker);
    }

    global class StockPriceDTO {
        public String name;
        public String ticker;
        public Decimal price;

        public StockPriceDTO() {
        }

        public StockPriceDTO(String name, String ticker, Decimal price) {
            this.name = name;
            this.ticker = ticker;
            this.price = price;
        }
    }

    global class StockApiResponse {
        public String message;
        public String errorCode;
        public StockApiResponse(String message, String errorCode) {
            this.message = message;
            this.errorCode = errorCode;
        }
        public StockApiResponse(String message) {
            this.message = message;
        }
    }
}
