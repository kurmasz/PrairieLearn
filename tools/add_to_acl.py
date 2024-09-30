# add_to_acl.py
#
# Add uids to a question's and/or assignment's ACL.
# This script assumes that exactly one entry in "allowAccess" contains a uids field.

import json
import sys


# This isn't part of the program. It is just 
# sample code to show you how to access data in a 
# .json file.
def print_assignment_info(data_file_name):
    f = open(data_file_name, "r")
    data_from_json = json.load(f)
    print(f'Title: {data_from_json["title"]}')

    for access_rule in data_from_json["allowAccess"]:
        if "uids" in access_rule:
            print(access_rule["uids"])

# Same of how to write .json as file.
def write_to_json(file_name, object):
    with open(file_name, 'w') as f:
       json.dump(object, f)

if (len(sys.argv) < 3):
    print("Usage: add_to_acl.py file name1 name2 name3 .... name_n")
    exit()
    
file_name = sys.argv[1]
usernames = sys.argv[2:]

# This runs the demo code above.
print_assignment_info(sys.argv[1])

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
