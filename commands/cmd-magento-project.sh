#!/usr/bin/env bash

# workspace-name: Magento Open Source (2.4.x)

# Installed by the Magento plugin (plugins.sh --install magento); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Magento Open Source store in a container: the community edition, release 2.4.9 or the
# 2.4.x release --version names, with its search engine, at https://<name>.ddev.site. With --install
# the store is installed with the workspace account as its administrator and, unless --sample-data no,
# with the sample catalog; with --add-users it also gets the default accounts: an administrator, an
# admin user with a role limited to Sales, and two customers with an address.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Set site version.
site_version="2.4.9";

# Distribution.
distribution_name="magento";
distribution_title="Magento Open Source";
distribution_webroot="pub";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/magento/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/magento/args/arg-magento.sh || exit 1 ;

shift $#;

magento_build ;
