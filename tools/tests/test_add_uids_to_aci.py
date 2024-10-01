###############################################################################
#
# test_add_uids_to_acl.py
#
# Tests to verify that add_uids_to_acl.py works correctly.
#
###############################################################################

import os
import re
import subprocess
import sys
import shutil
import unittest
import json
from deepdiff import DeepDiff


# from collections import namedtuple
# TestData = namedtuple('TestData', ['in', 'out', 'data_in'])

current_dir_name = os.path.dirname(__file__)
# This will have to be updated if this file moves.
script = f"{current_dir_name}/../add_uids_to_acl.py"
test_input_dir = f"{current_dir_name}/input"
test_output_dir = f"{current_dir_name}/output"


def run_script(parameters):
    return subprocess.run([sys.executable, script] + parameters, capture_output=True, text=True)


# def prepare_test(filename):
#    input = f"{test_input_dir}/{filename}"
#    output = f"{test_output_dir}/{filename}"
#    shutil.copyfile(input, output)
#    return TestData(input, output)


class TestCommandLine(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        assert os.path.exists(
            script), "add_uids_to_acl.py not found. Double-check script variable."

    def verify_usage(self, result):
        self.assertEqual(2, result.returncode)
        self.assertEqual(
            'Usage: add_uids_to_acl.py uid1 [uid2, uid3, ...] file1 [file2, file3, ...]\n', result.stderr)
        self.assertEqual('', result.stdout)

    def run_test(self, filename, script_runner):
        input = f"{test_input_dir}/{filename}"
        output = f"{test_output_dir}/{filename}"
        shutil.copyfile(input, output)

        data_in = None
        with open(input, "r") as f:
            data_in = json.load(f)

        # Run the script using _output_ not input; because the output is what gets replaced.
        # (We don't want input to change.)
        result = script_runner(output)
        self.assertEqual(0, result.returncode)
        self.assertEqual('', result.stdout)
        self.assertEqual('', result.stderr)

        data_out = None
        with open(output, "r") as f:
            data_out = json.load(f)

        return DeepDiff(data_in, data_out)

    def test_no_parameters(self):
        self.verify_usage(run_script([]))

    def test_one_filename_only(self):
        self.verify_usage(run_script(['infoAssignment.json']))

    def test_one_uid_only(self):
        self.verify_usage(run_script(['infoAssignment.json']))

    def test_filenames_only(self):
        result = run_script(
            ['infoAssignment1.json', 'infoAssignment2.json', 'infoAssignment3.json'])
        self.assertEqual(
            'Must specify at least one uid. (Uids must contain "@".)\n', result.stderr)
        self.assertEqual('', result.stdout)

    def test_uids_only(self):
        result = run_script(
            ['george@google.com', 'fred@aol.com', 'bob@smith.com'])
        self.assertEqual(
            'Must specify at least one filename. (Filenames must end with .json.)\n', result.stderr)
        self.assertEqual('', result.stdout)

    def test_one_uid_one_filename(self):
        diff = self.run_test('one_acl_with_uids.json', lambda filename: run_script(
            ['david@goliath.com', filename]))
        self.assertEqual(diff, {'iterable_item_added': {
                         "root['allowAccess'][0]['uids'][3]": 'david@goliath.com'}})


if __name__ == '__main__':
    unittest.main()
