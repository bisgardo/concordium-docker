#!/usr/bin/env python

import checksumdir
import csv
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import time


def run(out, source_dir, tmp_base_dir, source_hash, archive_ext):
    logging.debug('Running "%s" with ext "%s"', source_dir, archive_ext)
    tmp_dir = tempfile.mkdtemp(dir=tmp_base_dir)
    logging.debug('Using temporary directory "%s"', tmp_dir)
    start_time = time.time()
    archive_file = f'{source_dir}.tar.{archive_ext}'
    try:
        logging.debug('Compressing "%s" into "%s"', source_dir, archive_file)
        compression_time = compress(source_dir, archive_file)
        archive_size = os.path.getsize(archive_file)
        logging.debug('Compression time:  %.2f s', compression_time)
        logging.debug('Compressed size:   %d B', archive_size)
        logging.debug('Decompressing "%s" into "%s"', archive_file, tmp_dir)
        decompression_time = decompress(archive_file, tmp_dir)
        target_hash = checksumdir.dirhash(source_dir)
        logging.debug('Decompression time: %.2f s', decompression_time)
        out.writerow({
            'start_time': start_time,
            'archive_ext': archive_ext,
            'archive_size': archive_size,
            'compression_time': compression_time,
            'decompression_time': decompression_time,
            'source_hash': source_hash,
            'target_hash': target_hash,
        })
    finally:
        shutil.rmtree(tmp_dir)
        try:
            os.remove(archive_file)
        except OSError:
            pass


def compress(source_dir, target_file, flag='--auto-compress'):
    return run_timed(f'tar --create "{flag}" --file="{target_file}" "{source_dir}"')


def decompress(source_file, target_dir):
    return run_timed(f'tar --directory="{target_dir}" --extract --file="{source_file}"')


def run_timed(cmd):
    start = time.time()
    logging.debug('Running command: %s', cmd)
    res = subprocess.run(cmd, shell=True)
    res.check_returncode()
    return time.time() - start


source_dir = os.getenv('DATA_DIR')
tmp_base_dir = os.getenv('TMP_DIR', None)
log_level = os.getenv('LOG_LEVEL', 'INFO')
source_hash = os.getenv('SOURCE_HASH', None)

logging.basicConfig(level=log_level)

if __name__ == '__main__':
    out = sys.stdout
    if source_hash is None:
        logging.debug('Computing hash of original data')
        source_hash = checksumdir.dirhash(source_dir, hashfunc='md5')
        logging.debug('Hash of original data is %s', source_hash)
    logging.debug('Initializing writer')
    header = ['start_time', 'archive_ext', 'archive_size', 'compression_time', 'decompression_time', 'source_hash', 'target_hash']
    writer = csv.DictWriter(out, delimiter=',', fieldnames=header)
    writer.writeheader()

    logging.debug('Starting measurements')
    run(writer, source_dir, tmp_base_dir, source_hash, 'gz')
    run(writer, source_dir, tmp_base_dir, source_hash, 'gz')
    run(writer, source_dir, tmp_base_dir, source_hash, 'xz')
    run(writer, source_dir, tmp_base_dir, source_hash, 'xz')
    run(writer, source_dir, tmp_base_dir, source_hash, 'bzip2')
    run(writer, source_dir, tmp_base_dir, source_hash, 'bzip2')
    logging.debug('Done')
