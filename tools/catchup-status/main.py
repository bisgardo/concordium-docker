#!/usr/bin/env python

from pydantic import BaseModel
from pydantic.functional_validators import PlainValidator
from typing_extensions import Annotated

import requests
import argparse

# Parse CLI args.
# TODO: Add ability to select version rather than percentile? And default to version of tracked node?
#       Might also allow different percentiles for version lookup vs block lookup.
parser = argparse.ArgumentParser(prog='catchup-status', description='Status of catchup')
parser.add_argument('-n', '--network', type=str, default='mainnet')
parser.add_argument('-p', '--percentile', type=int, default=90)
parser.add_argument('-u', '--url', type=str)
parser.add_argument('node', type=str)
args = parser.parse_args()

# Use same settings for both percentiles for now.
network = args.network
version_percentile = args.percentile / 100
block_height_percentile = args.percentile / 100
url = args.url
node_name = args.node


def network_domain(n):
    if n == 'mainnet':
        return 'mainnet.concordium.software'
    return f'{n}.concordium.com'


def network_url(n):
    return 'https://dashboard.' + network_domain(n) + '/nodesSummary'


if not url:
    url = network_url(network)


# Set up model for data to be fetched.
def parse_version(c):
    [major, minor, patch] = c.split('.')
    return (major, minor, patch)


class NodeSummary(BaseModel):
    nodeName: str
    client: PlainValidator(parse_version)
    bestBlockHeight: int


# Fetch and decode JSON.
r = requests.get(url)
# TODO: Check status code.
summaries = [NodeSummary(**s) for s in r.json()]
#print(len(summaries))

# TODO: Validate...
#       ...and/or allow multiple nodes to be tracked?
node = [s for s in summaries if s.nodeName == node_name][0]
#print('node', node)

# Resolve version for the provided percentile.
sorted_versions = sorted([s.client for s in summaries])
version_percentile_rank = int(version_percentile * (len(sorted_versions)-1)) # we don't need perfect accuracy
version = sorted_versions[version_percentile_rank]
#print(version)

# Filter summaries based on resolved version (including newer versions - should we only match by exact version??).
valid_summaries = [s for s in summaries if s.client >= version]

# Resolve "current" best block height for the provided percentile amongst the "valid" nodes.
sorted_block_heights = sorted([s.bestBlockHeight for s in summaries])
block_height_percentile_rank = int(version_percentile * (len(sorted_versions)-1)) # we don't need perfect accuracy
block_height = sorted_block_heights[block_height_percentile_rank]

node_block_height = node.bestBlockHeight
node_block_height_pct = (node_block_height/block_height)*100

print(f'Current height: {block_height}')
print(f'Node height   : {node_block_height} ({node_block_height_pct:.1f}%)')

# TODO: Run the script periodically and use the recorded progress to give an esimate of the time remaining before the node is fully caught up (track the progress in percentage, not number of blocks).
