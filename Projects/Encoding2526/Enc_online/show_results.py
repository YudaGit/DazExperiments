from __future__ import print_function
from SimpleDB import Record, QuerySelect
import json
import sys

if sys.argv < 1:
    print("Please supply a participant UID")
    print("Usage: python show_results.py 72b61c874c8ae464967b8bb896e29d67")

query = "SELECT * FROM mall_experiments_participants WHERE uid='{}' ".format(sys.argv[0])
print(query)
sys.exit()
qs = QuerySelect()
for item in qs.sql(query):
    print(json.dumps(item, indent=4))

