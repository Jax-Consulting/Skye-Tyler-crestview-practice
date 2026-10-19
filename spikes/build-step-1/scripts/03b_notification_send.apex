// Build Step 1 spike (IPOP-47): send via the flow action to (1) the queue Id and (2) the user Id as a control.
Id spikeQueueId = [SELECT Id FROM Group WHERE DeveloperName = 'SPIKE_Notify_Queue' AND Type = 'Queue' LIMIT 1].Id;
Id targetCaseId = [SELECT Id FROM Case ORDER BY CreatedDate LIMIT 1].Id;
Map<String, String> recipientsByTitle = new Map<String, String>{
    'SPIKE-NOTIFY to QUEUE' => spikeQueueId,
    'SPIKE-NOTIFY to USER (control)' => UserInfo.getUserId()
};
for (String notificationTitle : recipientsByTitle.keySet()) {
    Flow.Interview notifyInterview = Flow.Interview.createInterview('SPIKE_SUB_Notify_Recipient', new Map<String, Object>{
        'varT_RecipientId' => recipientsByTitle.get(notificationTitle), 'varT_TargetId' => targetCaseId, 'varT_Title' => notificationTitle });
    notifyInterview.start();
    System.debug(LoggingLevel.ERROR, 'SPIKE|sent ' + notificationTitle);
}
