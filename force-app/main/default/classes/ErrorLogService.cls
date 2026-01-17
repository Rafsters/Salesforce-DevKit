public with sharing class ErrorLogService {
    public ErrorLogService() {
    }

    public static ErrorLog__c createErrorLog() {
        ErrorLog__c errorLog = new ErrorLog__c();
        return errorLog;
    }

    public static ErrorLog__c createErrorLogWithExcStackTrace(Exception e) {
        ErrorLog__c errorLog = new ErrorLog__c();
        errorLog.Description__c = e.getStackTraceString();
        return errorLog;
    }
}
