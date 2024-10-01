##############################################################################
#
# add_uids_to_acl.py
#
# Adds one or more uids to an assignment's access control list.
#
# * This script assumes that exactly one entry in "allowAccess" contains a
#   uids field.
# * uids to add and filenames can be specified in any order.
#   * Anything containing '@' is assumed to be a uid
#   * Filenames must end in .json
#
###############################################################################
import argparse
import json
import sys

# Add a list of uids to the acl for the given file
# (i.e., handle one file)


def add_to_acl(filename, uids):
    with open(filename, "r") as f:
        data_from_json = json.load(f)

    rules_with_uids = [
        r for r in data_from_json['allowAccess'] if 'uids' in r]

    if len(rules_with_uids) == 0:
        sys.stderr.write("No existing rules contain uids.\n")
        exit(1)
    elif len(rules_with_uids) > 1:
        sys.stderr.write("More than one rule contains uids.\n")
        exit(1)

    rule = rules_with_uids[0]
    rule['uids'] += uids

    with open(f"{filename}", 'w') as f:
        json.dump(data_from_json, f, indent=4)

#
# main
#


parser = argparse.ArgumentParser(prog='add_uids_to_acl',
                                 description='Adds uids to PL access control lists')
parser.add_argument('-b', "--backup", action='store_true',
                    help='create backup of original file')
parser.add_argument('parameters', metavar='foo', type=str, nargs='*',
                    help='input files and uids')
args = parser.parse_args()

if (len(args.parameters) < 2):
    sys.stderr.write(
        "Usage: add_uids_to_acl.py uid1 [uid2, uid3, ...] file1 [file2, file3, ...]\n")
    exit(2)

# Assume uids are always email addresses.
# Assume filenames always end in .json
uids = [item for item in args.parameters if '@' in item]
filenames = [item for item in args.parameters if item.endswith('.json')]

if len(uids) == 0:
    sys.stderr.write(
        'Must specify at least one uid. (Uids must contain "@".)\n')
    exit(1)

if len(filenames) == 0:
    sys.stderr.write(
        "Must specify at least one filename. (Filenames must end with .json.)\n")
    exit(1)

# Warn about parameters that are neither filenames nor uids
if (len(uids) + len(filenames) != len(args.parameters)):
    unknown = [item for item in args.parameters[2:]
               if item not in uids and item not in filenames]
    sys.stderr.write(f"WARNING: Unknown parameter {unknown}")

# Add the uids to each file
for filename in filenames:
    add_to_acl(filename, uids)

# TODO
# When the above works, allow the first parameter to be a pattern
# instead of just a single file: https://docs.python.org/3/library/glob.html
