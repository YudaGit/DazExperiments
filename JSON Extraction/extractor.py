import os, json, csv, datetime, gzip
from collections import OrderedDict
os.chdir('/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/JSON Extraction/')

def Save(uid, start_date_local, tasktype, Dict):
    start_date_local = start_date_local.replace(':', '-')
    scriptpath = os.getcwd()
    savepath = os.path.join(scriptpath, 'CSVresults')
    if not os.path.exists( savepath ):
        os.mkdir( savepath )
    os.chdir(savepath)
    with open( uid + '_' + start_date_local + '_' + tasktype +'.csv', 'w', newline='') as csv_file:
        writer = csv.writer( csv_file )
        writer.writerow( Dict.keys() )
        writer.writerows( zip(*Dict.values() ) )
    os.chdir(scriptpath)


def extraction(zipjsonfile, tasktype):
    # Load in file
    #f = open(jsonfile, 'r')
    with gzip.open(zipjsonfile, 'rt') as f:
        data = json.loads( f.read() )

    # Preallocate lists
    expIdentifiers = []
    trialIdentifiers = []
    SaveDict = OrderedDict()

    # Get all unique participant level data columns
    for d in data:
        expIdentifiers.extend( list(d.keys()) )
    expIdentifiers = list(set(expIdentifiers))
    expIdentifiers.pop(expIdentifiers.index('results'))

    # Get all trial level data columns
    for d in data:
        trialdata = d['results']
        if isinstance(trialdata, dict):
            #alt = trialdata['part_alt_behave']
            trialdata = json.loads(trialdata['data'])

        for rows in trialdata:
            trialIdentifiers.extend( rows.keys() )

    trialIdentifiers = list(set(trialIdentifiers))

    # Add Participant/Trial Columns to SaveDict
    for k in expIdentifiers:
        SaveDict[k] = []
    for k in trialIdentifiers:
        SaveDict[k] = []

    # Extract data into Save Dict
    for d in data:
        trialdata = d['results']
        if isinstance(trialdata, dict):
            trialdata = json.loads(trialdata['data'])

        for rows in trialdata:
            for key in trialIdentifiers:
                if key in rows.keys():
                    SaveDict[key].append( rows[key] )
                else:
                    SaveDict[key].append( '' )

        for key in expIdentifiers:
            if key in d.keys():
                SaveDict[key].extend( [ d[key] ] * len(trialdata) )
            else:
                SaveDict[key].extend( [''] * len(trialdata) )

    Save('CSVresults' , datetime.date.today().strftime("%Y-%m-%d"), tasktype, SaveDict )

extraction('Deadline_results-d0343eb8d3d6ca1e7725d64936ae7a3a_2026-04-27T00-16-05.json.gz', '')