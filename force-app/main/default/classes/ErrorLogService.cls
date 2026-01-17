public with sharing class ErrorLogService {
    public ErrorLogService() {
    }

    public static ErrorLog__c createErrorLogWithMessage(String message) {
        ErrorLog__c errorLog = new ErrorLog__c();
        errorLog.Description__c = message;
        return errorLog;
    }
}
