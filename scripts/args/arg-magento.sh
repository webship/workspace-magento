#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-v', '--version',
                    default="${site_version}",
                    help='The Magento Open Source 2.4 release to build, by its number. Example: --version 2.4.8-p3 [default %(default)s]')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install the store, with the workspace account as its administrator, in production mode.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts: an administrator, an admin user with a role limited to Sales, and two customers with an address, the ones the test scenarios log in as.')
parser.add_argument('-s', '--sample-data',
                    default="yes",
                    choices=['yes', 'no'],
                    help='With --install, add the sample catalog of the edition: products, categories, a customer and orders. Example: --sample-data no [default %(default)s]')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the store in a browser when it is ready.')
parser.add_argument('--php-version',
                    default="8.4",
                    choices=['8.4', '8.3'],
                    help='PHP version for the project container; 8.3 is for a 2.4.8 release. Example: --php-version 8.3 [default %(default)s]')
ARGEOF
