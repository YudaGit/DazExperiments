from __future__ import print_function
from os import getenv

NAME="FougnieTask2023_2"
EXPT_UID="06d9bffc703f14305bb7357074cf1eb6"
RESULTS_DIR="2023/FougnieTask2023_2/results"

PROLIFIC_COMPLETION_CODE = None

RESTRICTIONS = ["IE", "mobile", "tablet", "tv"]

# AWS Settings
AWS_DEFAULT_REGION = 'us-west-2'

# SimpleDB databases for experiments and participants
SDB_EXPERIMENTS = "mall_experiments"
SDB_EXPERIMENTS_PARTICIPANTS = "mall_experiments_participants"

# variable for REP crediting
REP_ON_CONSENT = False                                                       #both XXXX need to be replaced
REP_URL = 'https://unimelb.sona-systems.com/services/SonaAPI.svc/WebstudyCredit?experiment_id=1428&credit_token=c57762c2e70842fb98d827d9bfb840b6&survey_code={}'


DEBUG = True
if getenv('ExptEnv') == 'Production':
    DEBUG = False

if __name__ == "__main__":
    print(EXPT_UID)
