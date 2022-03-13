#!/usr/bin/env python3

import os
from query import query

url = os.environ['URL']

if __name__ == '__main__':
    res = query(url)
    print(res)
