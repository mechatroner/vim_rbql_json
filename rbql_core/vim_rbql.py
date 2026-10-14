import os
import sys
import codecs
import traceback
import subprocess
import tempfile
import time
import logging

import rbql
from rbql import rbql_json

vim_interface = None


class VimInterface:
    def __init__(self):
        import vim
        self.vim = vim

    def set_vim_variable(self, var_name, value):
        escaped_value = value.replace("'", "''")
        self.vim.command("let {} = '{}'".format(var_name, escaped_value))

    def report_error_to_vim(self, query_status, details):
        self.set_vim_variable('psv_query_status', query_status)
        self.set_vim_variable('psv_error_report', details)


class CLIVimMediator:
    def __init__(self):
        self.psv_variables = dict()

    def set_vim_variable(self, var_name, value):
        self.psv_variables[var_name] = value

    def report_error_to_vim(self, query_status, details):
        self.set_vim_variable('psv_query_status', query_status)
        self.set_vim_variable('psv_error_report', details)

    def save_report(self, dst):
        query_status = self.psv_variables.get('psv_query_status', 'Unknown Error')
        dst_table_path = self.psv_variables.get('psv_dst_table_path', '')
        report = self.psv_variables.get('psv_error_report', '')
        if not len(report):
            report = self.psv_variables.get('psv_warning_report', '')
        dst.write(query_status + '\n')
        dst.write(dst_table_path + '\n')
        if len(report):
            dst.write(report + '\n')


def get_random_suffix():
    return str(time.time()).split('.')[0]


def execute_python(src_table_path, rb_script_path, dst_table_path, pretty_indent):
    query = codecs.open(rb_script_path, encoding='utf-8').read()
    logging.info('Starting query: "{}"'.format(query))
    warnings = []
    try:
        rbql.query_json(query, src_table_path, dst_table_path, warnings, pretty_indent=pretty_indent, input_json_lines=False, output_json_lines=False, input_json_stream=True, output_json_stream=True)
        warning_report = '\n'.join(warnings)
        vim_interface.set_vim_variable('psv_warning_report', warning_report)
        vim_interface.set_vim_variable('psv_query_status', 'OK')
    except Exception as e:
        error_type, error_msg = rbql.exception_to_error_info(e)
        vim_interface.report_error_to_vim(error_type, error_msg)



def converged_execute(src_table_path, rb_script_path, pretty_indent):
    log_path = os.environ.get("VIM_RBQL_DEBUG_LOG_PATH")

    if log_path:
        logging.basicConfig(filename=log_path, level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
    else:
        logging.getLogger().addHandler(logging.NullHandler())

    try:
        tmp_dir = tempfile.gettempdir()
        table_name = os.path.basename(src_table_path)
        dst_table_name = '{}.txt'.format(table_name)
        dst_table_path = os.path.join(tmp_dir, dst_table_name)
        vim_interface.set_vim_variable('psv_dst_table_path', dst_table_path)
        pretty_indent = int(pretty_indent)
        assert pretty_indent <= 12 # Sanity check
        if not pretty_indent:
            pretty_indent = None
        execute_python(src_table_path, rb_script_path, dst_table_path, pretty_indent)
        logging.info('Completed. Results are in {}'.format(dst_table_path))
    except Exception as e:
        logging.error('Failed query: "{}"'.format(e))
        vim_interface.report_error_to_vim('Execution Error', str(e))


def run_execute(src_table_path, rb_script_path, pretty_indent):
    global vim_interface
    vim_interface = VimInterface()
    converged_execute(src_table_path, rb_script_path, pretty_indent)


def run_execute_cli(src_table_path, rb_script_path, pretty_indent):
    global vim_interface
    vim_interface = CLIVimMediator()
    converged_execute(src_table_path, rb_script_path, pretty_indent)
    vim_interface.save_report(sys.stdout)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('input_table_path', metavar='FILE', help='Read csv table from FILE')
    parser.add_argument('query_file', metavar='FILE', help='Read rbql query from FILE')
    parser.add_argument('pretty_indent', metavar='INT', help='Pretty indent')
    args = parser.parse_args()

    run_execute_cli(args.input_table_path, args.query_file, args.pretty_indent)


if __name__ == '__main__':
    main()
