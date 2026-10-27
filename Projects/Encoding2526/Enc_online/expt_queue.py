import boto3
import itertools 
import uuid 
import time 
import config
import json
import SQS
from SimpleDB import QuerySelect
import random

RETURN_QUEUE_PREFIX = 'return_'

ORDER_ITEMS = ['1','2','3']
N_STIMULI = 1000
COUNTERBALANCE_K = 1 # Every 1 (cycle) (3 * 1) conditions we are counterbalanced

RANDOM_SEED = 2025
random.seed(RANDOM_SEED)


#########################
## Create/Update/Poll Queue  
## 
## If there is an existing queue, create a new queue 
## with values updated to reflect current state. 
## For example, if we need to balance ABC, BCA, CAB
## And may need to add 3xABC, 2xBCA and no CAB
##

def poll_return_queue():
    """
    Queue for conditions returned by participants
    """
    
    client = boto3.client('sqs')
    res = client.list_queues(
        QueueNamePrefix='{}{}_'.format(RETURN_QUEUE_PREFIX, config.EXPT_UID)
        )
    queue_urls = res.get("QueueUrls")
    queues = []
    if queue_urls:
       queue_name = queue_urls[0].split("/")[-1]
       queues.append(queue_name)
    else:
        raise Exception("No queue")

    # Get the most recent queue
    # they are order by timestamp
    sorted_queues = sorted(queues)
    queue_name = sorted_queues[-1]
    queue = SQS.Queue(queue_name)
    poll_result = queue.poll()
    if not poll_result:
        return None
    
    res = json.loads( poll_result )['condition']
    return res


def update_return_queue(conditions):
    """
    Put returned conditions back on the queue.
    """
    if not isinstance(conditions, list):
        conditions = [conditions]
        
    items = []
    for i, k in enumerate(conditions):
        items.append({
            'condition': k,
            'batch': i,
            'uuid': str(uuid.uuid4())
            })           


    client = boto3.client('sqs')

    # Get a list of what queues are there
    # we will delete these later
    queues = client.list_queues(
        QueueNamePrefix="{}{}".format(RETURN_QUEUE_PREFIX, config.EXPT_UID)
        )
    queue_urls = queues.get("QueueUrls", [])
    queues = []
    if queue_urls:
       queue_name = queue_urls[0].split("/")[-1]
       queues.append(queue_name)
    else:
        raise Exception("No queue")

    # Get the most recent queue
    # they are order by timestamp
    sorted_queues = sorted(queues)
    queue_name = sorted_queues[-1]
 
    queue = SQS.Queue(queue_name)
    queue.push(items)       

    return {
            'status': 'success',
            'items': items
        }
    
    



def poll_queue():
    # Check return queue first
    return_queue_result = poll_return_queue()
    if return_queue_result:
        return return_queue_result
    
    client = boto3.client('sqs')
    res = client.list_queues(
        QueueNamePrefix='{}_'.format(config.EXPT_UID)
        )
    queue_urls = res.get("QueueUrls")
    queues = []
    if queue_urls:
       queue_name = queue_urls[0].split("/")[-1]
       queues.append(queue_name)
    else:
        raise Exception("No queue")

    # Get the most recent queue
    # they are order by timestamp
    sorted_queues = sorted(queues)
    queue_name = sorted_queues[-1]
    queue = SQS.Queue(queue_name)
    res = json.loads( queue.poll())['condition']
    return res


""" Create a queue if there isn't one,
    Recreate the queue if there is one.
"""
def update_queue():

    client = boto3.client('sqs')

    # Get a list of what queues are there
    # we will delete these later
    queues = client.list_queues(
        QueueNamePrefix=config.EXPT_UID
        )
    queue_urls = queues.get("QueueUrls", [])
  
    return_queues = client.list_queues(
        QueueNamePrefix="{}{}".format(RETURN_QUEUE_PREFIX, config.EXPT_UID)
        )
    queue_urls.extend( return_queues.get("QueueUrls", []) )
  
  
    # Create new queue 
    attrs = {
        "MessageRetentionPeriod": '1209600',
        "FifoQueue": 'true',
        "ContentBasedDeduplication": 'true'
        }

    queue_name = _make_queue_name()
    return_queue_name = _make_queue_name(prefix=RETURN_QUEUE_PREFIX)
    
    # Make primary queue
    response = client.create_queue(
            QueueName=queue_name,
            Attributes=attrs
            )
    
    # Make return queue, that prioritises conditions returned by participants.
     
    response = client.create_queue(
            QueueName=return_queue_name,
            Attributes=attrs
            )    
    
    # Get items to put of the queue
    items = _make_queue_data()

    # Add items to the new queue
    queue = SQS.Queue(queue_name)
    queue.push(items)

    # Delete the old queues
    for url in queue_urls:
        res = client.delete_queue(QueueUrl=url)


    return {
            'status': 'success',
            'items': items
        }
    

"""
Generate all the items for a queue, adjust the number according to the current item distribution in the current queue.
"""
def _make_queue_data():
    query = "SELECT * FROM mall_experiments_participants WHERE expt_uid = '{}' ".format(config.EXPT_UID)
    qs = QuerySelect(region="us-west-2")
    current_data = list(qs.sql(query))

    orderings = dict( [(x, 0) for x in ORDER_ITEMS] ) # ['a','b','c','d','e','f','g','h']

    # {'a': 0, 'b': 0, ...}
    for x in current_data:
        if not x.get("s3_results"): # Skip over records that have no results
            continue
        expt_cond = x.get("subexperiment") 
        if not expt_cond:
            continue
        if not expt_cond in ORDER_ITEMS:
            continue
        orderings[expt_cond] += 1

    # fast_fast-fast_slow
    items = []

    # {'a': 4, 'b': 7, ...}
    conditions = _create_counterbalanced_conditions()
    
    for i, k in enumerate(conditions):
        if orderings[k] > 0:  # Skip over conditions that have already been completed
            orderings[k] -= 1
            continue
         
        items.append({
            'condition': k,
            'batch': i,
            'uuid': str(uuid.uuid4())
            })           

    return items


def _create_counterbalanced_conditions(**kwargs):
    """
    Randomize the ordering of ORDER_ITEMS and counter balance. 
    """
    len_items = len(ORDER_ITEMS)
    multiple = len_items*COUNTERBALANCE_K
    n_adjust = multiple if (N_STIMULI % multiple) else 0 # Adjust if N doesn't divide equally by number of items
    cycles = int((N_STIMULI+n_adjust) // multiple)
    print("N", N_STIMULI)
    print("Length", len_items)
    print("n_adjust", n_adjust)
    print("cycles", cycles)
    print("K", COUNTERBALANCE_K)
    print("multiple", multiple)
    
    groups_k = ORDER_ITEMS * COUNTERBALANCE_K  # ORDER_ITEMS + ORDER_ITEMS + ... + ORDER_ITEMS
    
    conditions = []
    for i in range(cycles):
        random.shuffle(groups_k)
        conditions.extend(groups_k)
    
    return conditions
    
    
    
    
   
def _join_condition_name(x):
    return "-".join(list(x))


def _split_condition_name(x):
    return x.split("-")

def _make_queue_name(prefix=''):
    return "{}{}_{}.fifo".format(prefix, config.EXPT_UID, int(time.time())) 


if __name__ == '__main__':
    #d = _make_queue_data()
    #d = _create_counterbalanced_conditions()
    #print( json.dumps(d, indent=4) )
    update_queue()
