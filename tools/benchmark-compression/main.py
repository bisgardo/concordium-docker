#!/usr/bin/env python

import logging
import os
import shutil
import subprocess
import time


def run(data_dir):
    f = f'{data_dir}.tar.gz'
    ct, cs = compress(data_dir, f)
    print('Compression time:  ', ct, 's')
    print('Compressed size:   ', cs, 'B')
    dt = decompress(f, 'target')
    print('Decompression time:', dt, 's')


def compress(source_dir, target_file, flag='--auto-compress'):
    os.remove(target_file)
    return run_timed(f'tar --create "{flag}" --file="{target_file}" "{source_dir}"'), os.path.getsize(target_file)


def decompress(source_file, target_dir):
    shutil.rmtree(target_dir)
    os.makedirs(target_dir, exist_ok=True)
    return run_timed(f'tar --directory="{target_dir}" --extract --file="{source_file}"')


def run_timed(cmd):
    start = time.time()
    logging.debug('Running command:', cmd)
    res = subprocess.run([cmd], shell=True)
    res.check_returncode()
    return time.time() - start


if __name__ == '__main__':
    run('data')
