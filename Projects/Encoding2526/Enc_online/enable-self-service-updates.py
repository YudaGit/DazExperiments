"""
We will allow some users to self-service updates. This will entail 
them clicking a button in the CHDH dashboard that triggers an update
from our ZappaUpdateExpt LambdaDocker function.

Key features:
- A button in the CHDH dashboard for eligible users to trigger updates.
- Pulls the latest code from a Git repository.
- Uses AWS LambdaDocker function to perform the update.
- Logs the update process for auditing purposes.
- Ensures critical files are not overwritten during the update.
- in the dashboard, users will need feedback, so will need to see status messages through JobManager.

We have to ensure that key files for our LambdaExpt framework are not overwritten
during the update process. These files include:
- MallExperiment.py
- SimpleDB.py
- s3utils.py
- SQS.py
- user_utils.py
- zappa_settings.json

zappa_settings.json is critical for the Zappa deployment configuration and must remain unchanged.
This self-service script should put the zappa_settings.json file contained in this directory 
on to S3. It will then be pulled from S3 during the update process to ensure consistency.

In ZappaUpdateExpt, we will need to add logic to pull the zappa_settings.json file from S3
and overwrite the local versions of the files outlined above before redeploying the Lambda function.

This script should also add an entry to the experiment database of the format:
self_service_update: {
    gitrepo: <git repository URL>
} # Provides room to add more fields in the future.



"""

import json
import logging
import config
from s3utils import S3Helper
from SimpleDB import Record
from datetime import datetime, UTC
import sys
import git

if logging.getLogger().hasHandlers():
    logging.getLogger().setLevel(logging.INFO)
else:
    logging.basicConfig(level=logging.INFO)

logger = logging.getLogger(__name__)


#gitrepo_url = sys.argv[1]

local_gitrepo = git.Repo('./')  # Assumes the script is run in the git repository directory
remote = local_gitrepo.remotes['origin']
#remote_fetch_info = remote.fetch(dry_run=True)
gitrepo_url = remote.url

# Convert remotegit_url to https if it's an ssh url
if gitrepo_url.startswith("git@"):
    gitrepo_url = gitrepo_url.replace(".com:", ".com/").replace("git@", "https://")
# Convert

# Check that the gitrepo_url is a valid URL (basic check)
if not (gitrepo_url.startswith("http://") or gitrepo_url.startswith("https://")):
    logger.error("Invalid git repository URL provided.")
    sys.exit(1)

EXPT_UID = config.EXPT_UID

REGION_NAME = config.AWS_DEFAULT_REGION
ZAPPA_SETTINGS_FILE  = 'zappa_settings.json'
S3_BUCKET = 'chdhexpt'
SDB_EXPERIMENTS = config.SDB_EXPERIMENTS
YEAR = datetime.now().year




expt_record = Record(domain=SDB_EXPERIMENTS, key=EXPT_UID, region=REGION_NAME, s3_bucket=S3_BUCKET)
expt_record_details = expt_record.fetch()
if not expt_record_details:
    raise ValueError(f"Experiment record with EXPT_UID {EXPT_UID} not found in SimpleDB.")  

experiment_name = expt_record_details.get('experiment')
if not experiment_name:
    raise ValueError(f"Experiment name not found for EXPT_UID {EXPT_UID}.")

s3_zappa_settings_key = f'{YEAR}/{experiment_name}/{ZAPPA_SETTINGS_FILE}'
s3_url = f's3://{S3_BUCKET}/{s3_zappa_settings_key}'



s3helper = S3Helper(region_name=REGION_NAME)


# Step 1: Upload zappa_settings.json to S3
try:
    s3helper.save_file(
        S3_BUCKET, 
        s3_zappa_settings_key, 
        open(ZAPPA_SETTINGS_FILE, 'rb').read(), 
        content_type='application/json', 
        skip_json_dump=True)
    
    logger.info(f"Successfully uploaded {ZAPPA_SETTINGS_FILE} to S3 bucket {S3_BUCKET} with key {s3_zappa_settings_key}.")
except Exception as e:
    logger.error(f"Failed to upload {ZAPPA_SETTINGS_FILE} to S3: {e}")
    raise


# Step 2: Log the self-service update request in SimpleDB
try:
    update_info = {
        'self_service_update': {
            'enabled': True,
            'gitrepo': gitrepo_url,
            'timestamp': datetime.now(UTC).isoformat().split('.')[0] + 'Z',
            's3_zappa_settings': s3_url,
            #'zappa_stage': 'prod', # Could be parameterized if needed              
        }
    }
    print(update_info)
    expt_record.set_attributes(update_info, quote=True)
    expt_record.update()
    logger.info(f"Logged self-service update request for EXPT_UID {EXPT_UID}.")
except Exception as e:
    logger.error(f"Failed to log self-service update request: {e}")
    raise