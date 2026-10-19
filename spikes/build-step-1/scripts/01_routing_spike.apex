// Build Step 1 spike (IPOP-47): do Case assignment rules fire for flow-created Cases and on update?
// Uses the org's existing active "Standard" rule (Account country US + SLA Gold + Type contains Customer -> OrgFarm EPIC user).
// Note: this org has State/Country picklists on, so the test Account sets BillingCountryCode, not BillingCountry.
// Everything is rolled back - no data is left behind.
Savepoint savepointBeforeSpike = Database.setSavepoint();
try {
    Account spikeAccount = new Account(Name = 'SPIKE Routing', BillingCountryCode = 'US', SLA__c = 'Gold', Type = 'Customer - Direct');
    insert spikeAccount;
    Database.DMLOptions useRuleOptions = new Database.DMLOptions();
    // Finding: useDefaultRule = true did NOT fire the active rule in this org; passing the rule Id explicitly does.
    Id activeCaseRuleId = [SELECT Id FROM AssignmentRule WHERE SobjectType = 'Case' AND Active = true LIMIT 1].Id;
    useRuleOptions.assignmentRuleHeader.assignmentRuleId = activeCaseRuleId;

    // A: created by Flow Create Records (what the intake Screen Flow does)
    Flow.Interview createInterview = Flow.Interview.createInterview('SPIKE_SUB_Create_Case',
        new Map<String, Object>{ 'varT_AccountId' => spikeAccount.Id, 'varT_Subject' => 'SPIKE A flow insert' });
    createInterview.start();
    Id flowCaseId = (Id) createInterview.getVariableValue('varT_CaseId');
    System.debug(LoggingLevel.ERROR, 'SPIKE|A flow insert owner=' + [SELECT Owner.Name FROM Case WHERE Id = :flowCaseId].Owner.Name);

    // B: plain insert, no assignment header
    Case plainCase = new Case(AccountId = spikeAccount.Id, Subject = 'SPIKE B plain insert');
    insert plainCase;
    System.debug(LoggingLevel.ERROR, 'SPIKE|B plain insert owner=' + [SELECT Owner.Name FROM Case WHERE Id = :plainCase.Id].Owner.Name);

    // C: insert with the assignment-rule header (what the UI checkbox / API header does)
    Case headerCase = new Case(AccountId = spikeAccount.Id, Subject = 'SPIKE C header insert');
    headerCase.setOptions(useRuleOptions);
    insert headerCase;
    System.debug(LoggingLevel.ERROR, 'SPIKE|C header insert owner=' + [SELECT Owner.Name FROM Case WHERE Id = :headerCase.Id].Owner.Name);

    // D: update (Incomplete -> Submitted analogue) with no header
    plainCase.Status = 'Working';
    update plainCase;
    System.debug(LoggingLevel.ERROR, 'SPIKE|D plain update owner=' + [SELECT Owner.Name FROM Case WHERE Id = :plainCase.Id].Owner.Name);

    // D2: Flow Update Records path is the same as D (Flow has no assignment-header option)

    // E: update of the flow-created Case with the header
    Case headerUpdate = new Case(Id = flowCaseId, Status = 'Working');
    headerUpdate.setOptions(useRuleOptions);
    update headerUpdate;
    System.debug(LoggingLevel.ERROR, 'SPIKE|E header update owner=' + [SELECT Owner.Name FROM Case WHERE Id = :flowCaseId].Owner.Name);
} finally {
    Database.rollback(savepointBeforeSpike);
}
