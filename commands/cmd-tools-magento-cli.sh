#!/usr/bin/env bash

# Installed by the Magento plugin (plugins.sh --install magento); __WORKSPACE__ is the workspace it was installed into.
#
# The command line of the store (bin/magento) for one Magento Open Source project of this workspace,
# in its container: say what the store is, run a command, flush the cache, rebuild the indexes, change
# the mode, add or remove the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="magento";

ARGPARSE_DESCRIPTION="Run bin/magento on a Magento Open Source project of __WORKSPACE__: status, a command, the cache, the indexes, the mode, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/magento/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/magento/args/arg-magento-cli.sh || exit 1 ;

shift $#;

magento_cli_tool ;
