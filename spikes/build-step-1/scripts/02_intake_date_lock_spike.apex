// Build Step 1 spike (IPOP-47): does a lock validation rule block a System Administrator,
// and can a one-time migration still set the value on insert? Rolled back - no data left behind.
Savepoint savepointBeforeSpike = Database.setSavepoint();
try {
    System.debug(LoggingLevel.ERROR, 'SPIKE|running profile=' + [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name);
    Case migratedCase = new Case(Subject = 'SPIKE-LOCK migrated value');
    insert migratedCase;
    System.debug(LoggingLevel.ERROR, 'SPIKE|insert with locked value set: ALLOWED');
    migratedCase.Subject = 'SPIKE-LOCK changed value';
    try {
        update migratedCase;
        System.debug(LoggingLevel.ERROR, 'SPIKE|admin change after set: ALLOWED');
    } catch (DmlException lockException) {
        System.debug(LoggingLevel.ERROR, 'SPIKE|admin change after set: BLOCKED ' + lockException.getDmlType(0) + ' ' + lockException.getDmlMessage(0));
    }
    Case blankFirst = new Case(Subject = null);
    insert blankFirst;
    blankFirst.Subject = 'SPIKE-LOCK first stamp';
    update blankFirst;
    System.debug(LoggingLevel.ERROR, 'SPIKE|first stamp on update when prior blank: ALLOWED');
} finally {
    Database.rollback(savepointBeforeSpike);
}
