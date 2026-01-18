public with sharing class StockWrapper {
    public String name;
    public String ticker;
    public String industry;

    public static StockWrapper parse(String JSON) {
        return (StockWrapper) System.JSON.deserialize(JSON, StockWrapper.class);
    }
}
