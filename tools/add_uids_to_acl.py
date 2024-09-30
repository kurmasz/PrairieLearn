##############################################################################
#
# add_uids_to_acl.py
#
# Adds one or more uids to an assignment's access control list.
#
# This script assumes that exactly one entry in "allowAccess" contains a 
# uids field.
#
###############################################################################
import json
import sys


def add_to_acl(filename, uids):
    data_from_json = None
    with open(filename, "r") as f:
        data_from_json = json.load(f)

        rules_with_uids = [r for r in data_from_json['allowAccess'] if 'uids' in r]

        if len(rules_with_uids) == 0:
            sys.stderr.write("No existing rules contain uids")
            exit(1)
        elif len(rules_with_uids) > 1:
            sys.stderr.write("More than one rule contains uids")
            exit(1)

        print(rules_with_uids)

        rule = rules_with_uids[0]
        rule['uids'] += uids

    with open(f"{filename}.new.json", 'w') as f:
       json.dump(data_from_json, f, indent=4)

#
# main
#

if (len(sys.argv) < 3):
    print("Usage: add_uids_to_acl.py uid1 [uid2, uid3, ...] file1 [file2, file3, ...]")
    exit(0)
    
# Assume uids are always email addresses.
# Assume filenames always end in .json    
uids = [item for item in sys.argv if '@' in item]
filenames = [item for item in sys.argv if item.endswith('.json')]

if (len(uids) + len(filenames) != len(sys.argv)-1):
    unknown = [item for item in argv[2:] if item not in uids and item not in filenames]
    sys.stderr.write(f"WARNING: Unknown parameter {unknown}")

for filename in filenames:
    add_to_acl(filename, uids)

# TODO
# open the file
# determine wither there is exactly one access rule that contains uuids
#    if not, print an error and exit
# if there is exactly one
#   * copy the input file (in case we mess up) (https://docs.python.org/3/library/shutil.html)
#   * add all the names to the object,
#   * write the modified object out as a new .json file.

# When the above works, allow the first parameter to be a pattern 
# instead of just a single file: https://docs.python.org/3/library/glob.html
