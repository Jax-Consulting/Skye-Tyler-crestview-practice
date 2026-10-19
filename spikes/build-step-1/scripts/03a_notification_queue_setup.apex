// Build Step 1 spike (IPOP-47): throwaway Case queue with the running admin as its only member.
Group spikeQueue = new Group(Name = 'SPIKE Notify Queue', DeveloperName = 'SPIKE_Notify_Queue', Type = 'Queue');
insert spikeQueue;
insert new QueueSobject(QueueId = spikeQueue.Id, SobjectType = 'Case');
insert new GroupMember(GroupId = spikeQueue.Id, UserOrGroupId = UserInfo.getUserId());
System.debug(LoggingLevel.ERROR, 'SPIKE|queue created ' + spikeQueue.Id);
