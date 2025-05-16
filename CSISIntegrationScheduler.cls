global class CSISIntegrationScheduler implements Schedulable {
    private String batchType;
    private Integer batchSize;
    
    global CSISIntegrationScheduler() {
        this.batchType = 'all';
        this.batchSize = 100;
    }
    
    global CSISIntegrationScheduler(String batchType) {
        this.batchType = batchType;
        this.batchSize = 100;
    }
    
    global CSISIntegrationScheduler(String batchType, Integer batchSize) {
        this.batchType = batchType;
        this.batchSize = batchSize;
    }
    
    global void execute(SchedulableContext sc) {
        if (this.batchType == 'all' || this.batchType == 'event') {
            Database.executeBatch(new CSISEventBatch(), this.batchSize);
        }
        
        if (this.batchType == 'all' || this.batchType == 'order') {
            Database.executeBatch(new CSISOrderBatch(), this.batchSize);
        }
        
        if (this.batchType == 'all' || this.batchType == 'attendee') {
            Database.executeBatch(new CSISAttendeeBatch(), this.batchSize);
        }
        
        if (this.batchType == 'pending') {
            Database.executeBatch(new CSISEventBatch(true), this.batchSize);
            Database.executeBatch(new CSISOrderBatch(true), this.batchSize);
            Database.executeBatch(new CSISAttendeeBatch(true), this.batchSize);
        }
    }
    
    public static String scheduleAll() {
        String jobName = 'CSIS Integration - Daily Sync - All';
        String cronExp = '0 0 1 * * ?'; // Run at 1 AM daily
        return System.schedule(jobName, cronExp, new CSISIntegrationScheduler('all'));
    }
    
    public static String schedulePending() {
        String jobName = 'CSIS Integration - Hourly Sync - Pending';
        String cronExp = '0 0 * * * ?'; // Run hourly
        return System.schedule(jobName, cronExp, new CSISIntegrationScheduler('pending'));
    }
    
    public static String scheduleEvents() {
        String jobName = 'CSIS Integration - Daily Sync - Events';
        String cronExp = '0 0 2 * * ?'; // Run at 2 AM daily
        return System.schedule(jobName, cronExp, new CSISIntegrationScheduler('event'));
    }
    
    public static String scheduleOrders() {
        String jobName = 'CSIS Integration - Daily Sync - Orders';
        String cronExp = '0 0 3 * * ?'; // Run at 3 AM daily
        return System.schedule(jobName, cronExp, new CSISIntegrationScheduler('order'));
    }
    
    public static String scheduleAttendees() {
        String jobName = 'CSIS Integration - Daily Sync - Attendees';
        String cronExp = '0 0 4 * * ?'; // Run at 4 AM daily
        return System.schedule(jobName, cronExp, new CSISIntegrationScheduler('attendee'));
    }
}