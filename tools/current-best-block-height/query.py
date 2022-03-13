import json
from statistics import median
from urllib.request import urlopen

def query(url, threshold):
    with urlopen(url) as res:
         res_str = res.read()
    res_json = json.loads(res_str)
    best_block_heights = [ r.get('bestBlockHeight', 0) for r in res_json ]
    best_block_heights = [ h for h in best_block_heights if h >= threshold ]
    return int(median(best_block_heights))
