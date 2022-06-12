import psycopg2


def connect(host, database, port, user, password):
    return psycopg2.connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
    )


def query(connection, sql, args):
    with connection.cursor() as cursor:
        cursor.execute(sql, args)
        return cursor.fetchall()


def query_by_block_height_and_hash(connection, block_height, block_hash):
    sql = '''
        SELECT
            ati.account,                     -- returns bytes (memoryview); wrap in "encode(..., 'hex')" to convert to string
            summaries.block,                 -- returns bytes (memoryview); wrap in "encode(..., 'hex')" to convert to string
            summaries.timestamp,
            summaries.height,
            CAST(summaries.summary AS text)  -- convert JSON to string as it would otherwise be parsed as a dict
        FROM ati LEFT JOIN summaries ON ati.summary = summaries.id
        WHERE summaries.height = %s
        AND md5(
            CAST(
                (
                    ati.account,
                    summaries.block,
                    summaries.timestamp,
                    summaries.summary
                ) AS text
            )
        ) = %s
        ORDER BY ati.id
    '''
    return query(connection, sql, (block_height, block_hash,))


def query_by_address_bytes(connection, address_bytes):
    sql = '''
        SELECT
            ati.account,                     -- returns bytes (memoryview); wrap in "encode(..., 'hex')" to convert to string
            summaries.block,                 -- returns bytes (memoryview); wrap in "encode(..., 'hex')" to convert to string
            summaries.timestamp,
            summaries.height,
            CAST(summaries.summary AS text)  -- convert JSON to string as it would otherwise be parsed as a dict
        FROM ati LEFT JOIN summaries ON ati.summary = summaries.id
        WHERE ati.account = %s               -- accepts bytes; wrap in "decode(..., 'hex')" to convert from string
        ORDER BY ati.id
    '''
    return query(connection, sql, (address_bytes,))
