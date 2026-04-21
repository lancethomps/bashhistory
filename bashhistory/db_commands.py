#!/usr/bin/env python
import os
import sqlite3
from datetime import datetime, UTC
from getpass import getuser

from bashhistory import db_connection


class SQL:
  COLUMNS = [
    "command",
    "at",
    "host",
    "pwd",
    "user",
    "exit_code",
    "pid",
    "sequence",
  ]

  CREATE_COMMANDS: str = """
    DROP TABLE IF EXISTS commands
    ;

    CREATE TABLE commands (
      command   TEXT      NOT NULL,
      at        TIMESTAMP NOT NULL,
      host      TEXT      NOT NULL,
      pwd       TEXT      NOT NULL,
      user      TEXT      NOT NULL,
      exit_code INTEGER,
      pid       INTEGER,
      sequence  INTEGER
    )
    ;

    CREATE INDEX commands_at ON commands (at)
    ;

    CREATE INDEX commands_pwd ON commands (pwd)
    ;

    CREATE INDEX commands_exit_code ON commands (exit_code)
    ;
    """

  INSERT_COMMAND: str = """
    INSERT INTO commands(command, at, host, pwd, user, exit_code, pid, sequence)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    """


def create_db():
  db_conn = db_connection.connect(create_if_missing=False)
  db_conn.executescript(SQL.CREATE_COMMANDS)
  db_conn.commit()
  db_conn.close()


def insert_command(
  command: str,
  at: datetime = None,
  host: str = None,
  pwd: str = None,
  user: str = None,
  exit_code: int = None,
  pid: int = None,
  sequence: int = None,
  db_conn: sqlite3.Connection = None,
  commit: bool = True,
):
  if not at:
    at = datetime.now(UTC)

  if not host:
    host = os.uname()[1]

  if not pwd:
    try:
      pwd = os.getcwd()
    except:  # noqa: E722
      pwd = "UNKNOWN"

  if not user:
    user = getuser()

  close_after = False
  if not db_conn:
    close_after = True
    db_conn = db_connection.connect()

  db_conn.cursor().execute(SQL.INSERT_COMMAND, [
    command,
    at.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
    host,
    pwd,
    user,
    exit_code,
    pid,
    sequence,
  ]).close()

  if close_after:
    db_connection.close(db_conn, commit=True)
  elif commit:
    db_conn.commit()
