import boto3
import json
import uuid
import random
from datetime import datetime, timedelta
import pytz

class Queue:
    queue_type = 'fifo'
    def __init__(self, name, **kwargs):
        sqs = boto3.resource('sqs')
        self.__queue = sqs.get_queue_by_name(QueueName=name)
        self.__queue_name = name 
        for k,v in kwargs.items():
            setattr(self, k, v) # use override queue_type 'fifo' with 'standard' 


    def age_oldest_message(self):
        client = boto3.client('cloudwatch')
        five_minutes = 60 * 5
        end_time = datetime.utcnow().replace(tzinfo=pytz.UTC)
        start_time = end_time - timedelta(seconds=five_minutes) 
        result = client.get_metric_statistics(
            Period=five_minutes,
            StartTime=start_time,
            EndTime=end_time,
            Namespace='AWS/SQS',
            MetricName='ApproximateAgeOfOldestMessage',
            Statistics=['Average'],
            Dimensions=[{
                'Name': 'QueueName', 
                'Value': self.__queue_name
                }]
        )      
        datapoints = result.get('Datapoints')
        if not datapoints:
            return 0
       
        return datapoints[0]['Average'] 

    
        


    def poll(self):
        messages = self.__queue.receive_messages(MaxNumberOfMessages=1)
        if messages:
            message = messages[0]
            message_body = message.body
            message.delete()
            return message_body


    def push(self, items, delay=0, delay_increment=0):
        """
        delay: add delay to message
        delay_increment: make delay increase with number of messages
        """
        numberOfMessagePackets = len(items) // 10 + (len(items) % 10 != 0)
        itemCounter = 0
        delay -= delay_increment # setup for zeroed delay (will be + if delay > 0), see Handle delay below
        for i in range(0, numberOfMessagePackets):
            groupCount = 0
            messages = []
            MessageGroupId = str(uuid.uuid4())
            while (itemCounter < len(items) and groupCount < 10):
                msg = {
                    'Id': str(uuid.uuid4()),
                    'MessageBody': json.dumps(items[itemCounter])
                }
                if self.queue_type == 'fifo':
                    msg['MessageGroupId'] = MessageGroupId

                # Handle delay
                delay += delay_increment
                if delay > 0 and delay <= 900: # 15 minutes
                    msg['DelaySeconds'] = delay  # set delay 
                else:
                    delay = 0   # skip DelaySeconds and reset delay

                #msg['DelaySeconds'] = random.randint(120, 300)

                messages.append(msg)
                itemCounter += 1
                groupCount += 1
            res = self.__queue.send_messages(Entries=messages)
            #print(res)

