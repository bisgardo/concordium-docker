#!/usr/bin/env python3

import os
from query import query

url = os.getenv('URL')
threshold = int(os.getenv('THRESHOLD', '0'))

if __name__ == '__main__':
    res = query(url, threshold)
    print(res)
