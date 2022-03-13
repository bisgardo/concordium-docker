import json
from statistics import median
from urllib.request import urlopen

def query(url):
    with urlopen(url) as res:
         res_str = res.read()
    res_json = json.loads(res_str)
    best_block_heights = [ r.get('bestBlockHeight', 0) for r in res_json ]
    return int(median(best_block_heights))
