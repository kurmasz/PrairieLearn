##############################################################################
#
# set_acl_date.py
#
# Sets an ACL's the startDate and/or endDate.
#
###############################################################################

import argparse


def set_acl_date(filename, startDate, endDate):
    pass
    # Open the file, parse as json
    # set every startDate in the ACL to startDate if startDate != None
    # set every endDate in the ACL to endDate if endDate != None
    # write out .json file


#
# Main
#

parser = argparse.ArgumentParser(prog='add_uids_to_acl',
                                 description='Adds uids to PL access control lists')
parser.add_argument('-b', "--backup", action='store_true',
                    help='create backup of original file')
parser.add_argument('-s', "--start", type=str, help="the startDate", nargs='+')
parser.add_argument('-e', "--end", type=str, help="the startDate", nargs='+')
parser.add_argument('filenames', metavar='filename', type=str, nargs='+',
                    help='input files')
args = parser.parse_args()

print(args.filenames)
print(f"startDate = {args.start}")
print(f"endDate = {args.end}")

# If args.start == now, then args.start = the current date
# If args.end == now, then args.end = the current date

# Make sure that args.start and args.end is a valid date (in the valid format)

# iterate over args.filename and call set_acl_date
