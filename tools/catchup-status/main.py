#!/usr/bin/env python

from pydantic import BaseModel
from pydantic.functional_validators import PlainValidator
from typing_extensions import Annotated

import argparse
import requests
import time

# Parse CLI args.
# TODO: Add ability to select version rather than percentile? And default to version of tracked node?
#       Might also allow different percentiles for version lookup vs block lookup.
parser = argparse.ArgumentParser(prog='catchup-status', description='Status of catchup')
parser.add_argument('-n', '--network', type=str, default='mainnet')
parser.add_argument('-p', '--percentile', type=int, default=90)
parser.add_argument('-u', '--url', type=str, default='')
parser.add_argument('-s', '--period-secs', type=int, default=2)
parser.add_argument('node', type=str)
args = parser.parse_args()

# Use same settings for both percentiles for now.
network = args.network
version_percentile = args.percentile / 100
block_height_percentile = args.percentile / 100
url = args.url
sleep_secs = args.period_secs
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


def run(url, node_name, version_percentile, block_height_percentile):
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

    return block_height, node.bestBlockHeight


previous_pct = 0
while True:
    block_height, node_block_height = run(url, node_name, version_percentile, block_height_percentile)

    height_pct = 100*node_block_height/block_height
    #print('previous_pct',previous_pct)
    #print('height_pct',height_pct)

    secs_remaining = None
    if previous_pct:
        progress_pct = height_pct - previous_pct
        #print('progress_pct',progress_pct)
        if progress_pct > 0:
            progress_pct_per_sec = progress_pct / sleep_secs

            pct_remaining = 100 - height_pct
            secs_remaining = pct_remaining / progress_pct_per_sec

    print(f'Current height: {block_height}')
    print(f'Node height   : {node_block_height} ({height_pct:.1f}%)')
    time_remaining_str = 'N/A'
    if secs_remaining:
        secs_remaining_str = str(secs_remaining)
        mins_remaining_str = str(secs_remaining/60)
        time_remaining_str = f'{secs_remaining_str}s ({mins_remaining_str}m)'
    print(f'Time remaining: {time_remaining_str}')

    previous_pct = height_pct
    time.sleep(sleep_secs)
