#!/usr/bin/env python
from typing import Dict, List

from bashhistory.bh_configs import BashHistoryColorArgs, BashHistoryConfig, SelectScriptArgs
from ltpylib.colors import colored
from ltpylib.inputs import select_prompt


def colorize_result(config: BashHistoryConfig, args: BashHistoryColorArgs, column: str, value) -> str:
  if value is None:
    return ""

  if args.no_color:
    return value

  color = config.column_colors.get(column)
  if color is not None:
    return colored(color, value)

  return value


def create_results_output(config: BashHistoryConfig, args: SelectScriptArgs, results: List[dict], column_max_lengths: Dict[str, int]) -> List[str]:
  output_lines = []

  format_str_parts = []
  for column in args.columns:
    col_length = column_max_lengths.get(column)

    if not args.no_color and column in config.column_colors:
      col_length += len(colored(config.column_colors.get(column), ""))

    format_str_parts.append("{:" + str(col_length) + "}")

  format_str = " | ".join(format_str_parts)
  output_lines.append(format_str.format(*[colorize_result(config, args, column, column) for column in args.columns]))

  for result in results:
    result_parts = [colorize_result(config, args, column, result.get(column)) for column in args.columns]
    line = format_str.format(*result_parts)
    output_lines.append(line)

  return output_lines


def ask_user_to_select_command(results: List[dict], output_lines: List[str]) -> List[str]:
  selected_results = []
  index_max_chars = len(str(len(output_lines) - 1))
  index_line_format_str = "%" + str(index_max_chars) + "s: %s"
  selections = select_prompt(
    [(index_line_format_str % (index, line)) for index, line in enumerate(output_lines[1:], start=1)],
    header="Please select the command from the list below.\n  " + (" " * index_max_chars) + output_lines[0],
    no_sort=True,
    layout="reverse",
    multi=True,
    ansi=True,
    include_select_all_bind=True,
  ).splitlines(keepends=False)

  for selection in selections:
    result_index = int(selection.split(":", 1)[0]) - 1
    selected_result = results[result_index]
    selected_results.append(selected_result.get("command"))

  return selected_results
