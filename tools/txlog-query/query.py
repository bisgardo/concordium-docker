#!/usr/bin/env python

import psycopg2


def connect(host, database, port, user, password):
    return psycopg2.connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
    )


def query_all_accounts(connection):
    with connection.cursor() as cursor:
        sql = '''SELECT DISTINCT(ati.account) FROM ati'''
        cursor.execute(sql, ())
        return cursor.fetchall()


def query_by_address_bytes(connection, address_bytes):
    with connection.cursor() as cursor:
        sql = '''
                SELECT
                    ati.account,         -- returns bytes; wrap in "encode(..., 'hex')" to convert to string
                    summaries.block,     -- returns bytes; wrap in "encode(..., 'hex')" to convert to string
                    summaries.timestamp,
                    summaries.height,
                    summaries.summary
                FROM ati LEFT JOIN summaries ON ati.summary = summaries.id
                WHERE ati.account = %s   -- accepts bytes; wrap in "decode(..., 'hex')" to convert from string
                ORDER BY ati.id
            '''
        cursor.execute(sql, (address_bytes,))
        return cursor.fetchall()
