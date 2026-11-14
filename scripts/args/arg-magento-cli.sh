#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Magento Open Source project in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A command to run in the project, without the leading php bin/magento. Example: --run "module:status"')
parser.add_argument('-k', '--flush-cache',
                    action='store_true',
                    default=False,
                    help='Flush the cache of the store.')
parser.add_argument('-x', '--reindex',
                    action='store_true',
                    default=False,
                    help='Rebuild every index of the store.')
parser.add_argument('-m', '--mode',
                    default="_none_",
                    choices=['production', 'developer'],
                    help='Change the mode of the store. production compiles the code and deploys the static content; developer serves the files as they are. Example: --mode developer')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts: an administrator, an admin user with a role limited to Sales, and two customers with an address. An account that is already there is left as it is.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts.')
ARGEOF
