"""
Usage: python manual-update-result.py results/results-9b620dd3866fca8d1fabecd6193b732b.json

"""


from SimpleDB import Record
import config 
import json
from dateutil.parser import parse
import sys
import MallExperiment as me

import sys


def query_yes_no(question, default="yes"):
    """Ask a yes/no question via raw_input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
            It must be "yes" (the default), "no" or None (meaning
            an answer is required of the user).

    The "answer" return value is True for "yes" or False for "no".
    """
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        sys.stdout.write(question + prompt)
        choice = input().lower()
        if default is not None and choice == "":
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no' " "(or 'y' or 'n').\n")



DATE_FORMAT = '%Y-%m-%dT%H:%M:%S'

me_expt = me.Expt(domain=config.SDB_EXPERIMENTS_PARTICIPANTS)


res = None
with open(sys.argv[1]) as fp:
    res = json.load(fp)

uid = res['uid']
start_date_local = res['start_date_local']
end_date_local = res['end_date_local']
date_offset = res['date_offset']


s3_bucket = 'chdhexpt'
s3_key = '{}/{}.json'.format(config.RESULTS_DIR, uid)
s3_results = 's3://{}/{}'.format(s3_bucket, s3_key)

me_expt.save_S3(s3_bucket, s3_key, res['results'])

attrs = {
    's3_results': s3_results,
    'status': '3',
    'start_date_local': parse(res['start_date_local']).strftime(DATE_FORMAT),
    'end_date_local': parse(res['end_date_local']).strftime(DATE_FORMAT),
    'date_offset': res['date_offset'],
}

print (attrs)

if query_yes_no("Update participant record?"):
    rec = Record(domain=config.SDB_EXPERIMENTS_PARTICIPANTS, key=uid)
    rec.set_attributes(attrs, True)
    rec.update()






