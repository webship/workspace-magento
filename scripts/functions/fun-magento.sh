#!/usr/bin/env bash

# Magento Open Source for the Webship Workspace: build a store, run its command line, add its
# default accounts, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install magento` in core/scripts/plugins/magento/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in the project's container
# (DDEV by default: `ddev exec php bin/magento …`), never on the host. The plugin is the whole of
# the platform: the build, the accounts and the testing hook are here, and the only things it asks
# of the workspace are its general helpers (trim_project_name, drop_database, ddev_up,
# ddev_nodejs_version).
#
# Only the community edition is built: Magento Open Source 2.4. The packages come from the public
# Mage-OS mirror of the Magento Open Source packages, which serves the same releases as the
# vendor's repository without access keys, so a build needs no account anywhere. The payment
# gateway and data-export modules bundled with the edition are left out at install, so nothing in
# the store calls a service outside it, and the installer is given the container's own database
# values (db / db / db) and nothing personal.
#
# The container tool calls a store the project type `magento2`, and the row menus of the dashboard
# ask for the user list under that name, so the three account functions carry both names:
#   set_magento_users, set_magento2_users        the default accounts   (cmd-tools-add-users.sh <project> magento)
#   add_magento_users, add_magento2_users        create them in the store (the same tool, and --add-users of the builder)
#   cancel_magento_users, cancel_magento2_users  delete them            (cmd-tools-cancel-users.sh <project> magento)
#   testing_configure_magento                    the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a store is tested with, and the release line it is required at.
readonly MAGENTO_STEPS_PACKAGE='@webship-js/magento-steps';
readonly MAGENTO_STEPS_VERSION='^2.0.0';

# Where the packages come from: the public Mage-OS mirror of the Magento Open Source packages.
# No access keys, no account.
readonly MAGENTO_MIRROR='https://mirror.mage-os.org/';

# The project the mirror serves for the community edition, the line this plugin builds and the
# release it was proven on.
readonly MAGENTO_PROJECT='magento/project-community-edition';
readonly MAGENTO_LINE='2.4';
readonly MAGENTO_PROVEN_VERSION='2.4.9';

# The container of a store: the project type, the database, the search engine and its memory.
readonly MAGENTO_PROJECT_TYPE='magento2';
readonly MAGENTO_DATABASE='mariadb:11.4';
readonly MAGENTO_SEARCH_ADDON='ddev/ddev-opensearch';
readonly MAGENTO_SEARCH_ADDON_SOURCE='https://github.com/ddev/ddev-opensearch.git';
readonly MAGENTO_SEARCH_TAG='3';
readonly MAGENTO_SEARCH_HEAP='512m';

# A store with its search engine uses about 2 GB of memory: a build does not start with less free.
readonly MAGENTO_MEMORY_NEEDED=2048;

# The first path segment of the admin panel. The installer gives it a random name unless told; the
# builder pins it, so the address is the same in every project and the test suite knows it.
readonly MAGENTO_ADMIN_PATH='admin';

# The store's own rule for the password of an admin user.
readonly MAGENTO_PASSWORD_LENGTH=7;

# The command line of the store, from the root of the project.
readonly MAGENTO_CONSOLE='php bin/magento';
# Compiling the code and deploying the static content need more memory than the command line's default.
readonly MAGENTO_CONSOLE_HEAVY='php -d memory_limit=2G bin/magento';

# Modules the store is installed without. They are left out at install time, not disabled
# afterwards: a module disabled later leaves its database triggers behind, and the next order fails
# on a column that is gone.
#   - Two-factor authentication for admin users: a local test site cannot ask a person for a code.
#     Never leave these out on a store that is on the internet.
#   - The admin notification feed, the usage-data question and the release notification: they
#     fetch from outside, or ask the first admin user who logs in a question.
#   - The payment gateway and data-export modules bundled with the edition. Not configured, they
#     still make every storefront page load scripts from the gateway's servers and the checkout an
#     asset of the payment provider. A store built here has the offline methods of the edition.
readonly MAGENTO_DISABLED_MODULES='Magento_AdminAdobeImsTwoFactorAuth,Magento_TwoFactorAuth,Magento_AdminNotification,Magento_AdminAnalytics,Magento_ReleaseNotification,PayPal_Braintree,PayPal_BraintreeCustomerBalance,PayPal_BraintreeGiftCard,PayPal_BraintreeGiftCardAccount,PayPal_BraintreeGiftWrapping,PayPal_BraintreeGraphQl,PayPal_BraintreeReward,Magento_PaymentServicesBase,Magento_PaymentServicesDashboard,Magento_PaymentServicesPaypal,Magento_PaymentServicesPaypalGraphQl,Magento_PaymentServicesSaaSExport,Magento_ServiceProxy,Magento_ServicesConnector,Magento_ServicesId,Magento_ServicesIdGraphQlServer,Magento_ServicesIdLayout,Magento_SaaSCommon,Magento_DataExporter,Magento_SalesDataExporter,Magento_StoreDataExporter';

# The settings of a local store, one "path value" per line: the offline payment and shipping
# methods of the edition, and a sign-in that behaves the same way every time (a long admin session,
# no secret key in admin addresses, one admin account in two browsers, no forced password change,
# no lock after failed sign-ins, no CAPTCHA, no usage data sent). They are for a store on this
# machine and for tests: never copy them to a store that is on the internet.
readonly MAGENTO_LOCAL_SETTINGS='admin/security/session_lifetime 31536000
admin/security/use_form_key 0
admin/security/admin_account_sharing 1
admin/security/password_is_forced 0
admin/security/password_lifetime 0
admin/security/lockout_failures 0
admin/captcha/enable 0
customer/captcha/enable 0
customer/password/lockout_failures 0
analytics/subscription/enabled 0
web/cookie/cookie_lifetime 86400
web/cookie/cookie_restriction 0
checkout/options/guest_checkout 1
carriers/flatrate/active 1
carriers/freeshipping/active 1
carriers/freeshipping/free_shipping_subtotal 0
payment/checkmo/active 1
catalog/review/allow_guest 1';

# The default accounts: an admin user with every right, an admin user with a role limited to Sales,
# and two customers with an address, the ones a scenario logs in as. Accounts are configuration,
# created once in the store; a test suite never creates or deletes one. An admin user logs in by
# its user name, a customer by its e-mail address. The role is the role of an admin user, or "Customer".
# The administrator the installer makes is the workspace account and is not on this list: the
# administrator here is a test account of its own, so the workspace account is in no test.
function set_magento_users() {
  users=(administrator sales customer shopper);
  local kinds=(admin admin customer customer) roles=('Administrators' 'Sales' 'Customer' 'Customer') ;
  local firstnames=(Store Sally Casey Sam) lastnames=(Admin Sales Customer Shopper) ;
  local streets=('' '' '100 Main Street' '200 Market Street') cities=('' '' 'Austin' 'San Francisco') ;
  local regions=('' '' 'TX' 'CA') postcodes=('' '' '78701' '94105') phones=('' '' '5125550100' '4155550100') i user ;
  for i in "${!users[@]}" ; do
    user="${users[$i]}" ;
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_role" '%s' "${roles[$i]}" ;
    printf -v "user_${user}_kind" '%s' "${kinds[$i]}" ;
    printf -v "user_${user}_firstname" '%s' "${firstnames[$i]}" ;
    printf -v "user_${user}_lastname" '%s' "${lastnames[$i]}" ;
    printf -v "user_${user}_street" '%s' "${streets[$i]}" ;
    printf -v "user_${user}_city" '%s' "${cities[$i]}" ;
    printf -v "user_${user}_region" '%s' "${regions[$i]}" ;
    printf -v "user_${user}_postcode" '%s' "${postcodes[$i]}" ;
    printf -v "user_${user}_phone" '%s' "${phones[$i]}" ;
  done
}

# Is this folder a store? Its DDEV project type says so.
function magento_is_project() {
  local project_path="$1";
  grep -qE "^type:[[:space:]]*\"?${MAGENTO_PROJECT_TYPE}\"?[[:space:]]*$" "${project_path}/.ddev/config.yaml" 2>/dev/null ;
}

# Is the store installed? The installer writes both files of app/etc, and nothing else does.
function magento_is_installed() {
  local project_path="$1";
  [ -f "${project_path}/app/etc/env.php" ] && [ -f "${project_path}/app/etc/config.php" ] ;
}

# The first path segment of the admin panel of a project, from its own configuration; the pinned
# one when there is none to read.
function magento_admin_path() {
  local project_path="$1" front ;
  front="$(sed -n "s/.*'frontName'[[:space:]]*=>[[:space:]]*'\([^']*\)'.*/\1/p" "${project_path}/app/etc/env.php" 2>/dev/null | head -1)" ;
  printf '%s' "${front:-${MAGENTO_ADMIN_PATH}}" ;
}

# Megabytes of memory this machine has available.
function magento_memory_available() {
  awk '$1 == "MemAvailable:" { printf "%d", $2 / 1024 }' "${MAGENTO_MEMINFO:-/proc/meminfo}" 2>/dev/null ;
}

# Go to the project a tool was asked about, or say why not.
function magento_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! magento_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Magento Open Source project (its .ddev/config.yaml does not say type: ${MAGENTO_PROJECT_TYPE})." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# Run the command line of the store in the container of the project the shell is in. Every
# argument is quoted for the container's shell, so one with a space arrives as one argument.
function magento_console() {
  local line="${MAGENTO_CONSOLE}" arg ;
  for arg in "$@" ; do
    line="${line} $(printf '%q' "${arg}")" ;
  done
  ddev exec "${line}" ;
}

# Run a command that downloads, up to three times: a download that was cut short is asked for again.
function magento_retry() {
  local try ;
  for try in 1 2 3 ; do
    "$@" && return 0 ;
    [ "${try}" -lt 3 ] && echo "  That did not finish (try ${try} of 3): once more in ${MAGENTO_RETRY_PAUSE:-10} seconds." && sleep "${MAGENTO_RETRY_PAUSE:-10}" ;
  done
  return 1 ;
}

# A heading for a part of the build, with the time: a store takes minutes to build.
function magento_step() {
  printf '\n=== %s (%s) ===\n' "$1" "$(date +%H:%M:%S)" ;
}

# The search engine the store requires, in the project the shell is in: OpenSearch, from the
# container tool's own add-on. An older container tool than the add-on asks for gets the same
# add-on from a clone with the version constraint taken out; the container tool itself is left
# as it is.
function magento_add_search() {
  local compose='.ddev/docker-compose.opensearch.yaml' ;
  if [ ! -f "${compose}" ] ; then
    if ! ddev add-on get "${MAGENTO_SEARCH_ADDON}" ; then
      echo "  The add-on asks for a newer container tool than this machine has: taking the same add-on from a clone, without its version constraint." ;
      local addon ; addon="$(mktemp -d)" ;
      magento_retry git clone -q --depth 1 "${MAGENTO_SEARCH_ADDON_SOURCE}" "${addon}/ddev-opensearch" \
        && sed -i '/^ddev_version_constraint:/d' "${addon}/ddev-opensearch/install.yaml" \
        && ddev add-on get "${addon}/ddev-opensearch" ;
      rm -rf "${addon}" ;
    fi
  fi
  if [ ! -f "${compose}" ] ; then
    echo "The search engine add-on (${MAGENTO_SEARCH_ADDON}) could not be installed." ;
    return 1 ;
  fi
  printf 'OPENSEARCH_TAG=%s\n' "${MAGENTO_SEARCH_TAG}" > .ddev/.env.opensearch ;
  magento_trim_search "${compose}" "${MAGENTO_SEARCH_HEAP}" ;
}

# Keep of the add-on what a store needs: the engine. Its dashboards service goes (another 1.5 GB
# image and a second Node process), the engine is not published through the shared router (the
# store reaches it inside the project, at opensearch:9200), and its heap is limited.
function magento_trim_search() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys

path, heap = sys.argv[1:3]
text = open(path).read()
before = text
text = text.replace('#ddev-generated\n', '# From the ddev/ddev-opensearch add-on: the engine only, inside the project, with a limited heap.\n', 1)
text = re.sub(r'\n  opensearch-dashboards:.*?(?=\n  web:)', '\n', text, flags=re.S)
text = re.sub(r'^[ \t]*- "?(VIRTUAL_HOST|HTTP_EXPOSE|HTTPS_EXPOSE)=[^\n]*\n', '', text, flags=re.M)
text = re.sub(r'OPENSEARCH_JAVA_OPTS=[^"\n]*', 'OPENSEARCH_JAVA_OPTS=-Xms%s -Xmx%s' % (heap, heap), text)
if text != before:
    open(path, 'w').write(text)
PYEOF
}

# Download the code into the project the shell is in: the project of the edition from the mirror,
# then its packages. Composer is run in the container itself, in two steps. The container tool's
# own `composer create-project` tries each option with a dry run first and holds what the dry run
# prints until it ends; with the several hundred packages of the edition an older container tool
# then waits on itself and never comes back. Run again, it starts from a clean copy of the project
# and goes on with the packages that are still missing.
function magento_download() {
  local version="$1" tmp='/tmp/magento-project' ;
  ddev exec "rm -rf ${tmp} && composer create-project --repository-url='${MAGENTO_MIRROR}' '${MAGENTO_PROJECT}:${version}' ${tmp} --no-interaction --prefer-dist --no-install \
    && cp -a ${tmp}/. /var/www/html/ && rm -rf ${tmp}" \
    && ddev composer install --no-interaction --prefer-dist ;
}

# Apply the settings of a local store to the project the shell is in.
function magento_local_settings() {
  local path value command='' ;
  while read -r path value ; do
    [ -n "${path}" ] && command="${command}${MAGENTO_CONSOLE} config:set -q '${path}' '${value}' && " ;
  done <<< "${MAGENTO_LOCAL_SETTINGS}" ;
  ddev exec "${command}true" ;
}

# Put the store of the project the shell is in into a mode. Production compiles the code and
# deploys the static content; developer serves the files as they are.
function magento_set_mode() {
  local mode="$1" ;
  if [ "${mode}" == 'production' ] ; then
    ddev exec "${MAGENTO_CONSOLE} deploy:mode:set production --skip-compilation \
      && ${MAGENTO_CONSOLE_HEAVY} setup:di:compile \
      && ${MAGENTO_CONSOLE_HEAVY} setup:static-content:deploy -f --jobs=2 en_US" ;
  else
    ddev exec "${MAGENTO_CONSOLE} deploy:mode:set developer" ;
  fi
}

# Build a store from nothing: the container, the search engine, the code, and with --install the
# store itself.
function magento_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${VERSION:-${site_version:-${MAGENTO_PROVEN_VERSION}}}" ;
  local php_version="${PHP_VERSION:-${site_php_version:-8.4}}" ;
  local docroot="${distribution_webroot:-pub}" ;
  local started ; started="$(date +%s)" ;

  if [[ ! "${version}" =~ ^2\.4\.[0-9]+(-p[0-9]+)?$ ]] ; then
    echo "This builder makes a Magento Open Source ${MAGENTO_LINE} store: --version is a ${MAGENTO_LINE}.x number such as ${MAGENTO_PROVEN_VERSION} or 2.4.8-p3." ;
    exit 1 ;
  fi
  if [ "${INSTALL}" == 'yes' ] ; then
    if [ "${#account_pass}" -lt "${MAGENTO_PASSWORD_LENGTH}" ] || [[ ! "${account_pass}" =~ [0-9] ]] || [[ ! "${account_pass}" =~ [A-Za-z] ]] ; then
      echo "The store asks an admin user for a password of ${MAGENTO_PASSWORD_LENGTH} characters or more with both letters and digits, and the workspace account's is not one." ;
      echo "Change account: pass in core/config/settings.yml, or build without --install." ;
      exit 1 ;
    fi
  fi
  local memory ; memory="$(magento_memory_available)" ;
  if [ -n "${memory}" ] && [ "${memory}" -lt "${MAGENTO_MEMORY_NEEDED}" ] ; then
    echo "A store with its search engine uses about 2 GB of memory, and this machine has ${memory} MB available." ;
    echo "Stop a project that is not in use, then build again." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  magento_step "The container: PHP ${php_version}, ${MAGENTO_DATABASE}, OpenSearch ${MAGENTO_SEARCH_TAG}" ;
  # The installer writes the settings of the store itself, so the container tool manages none.
  ddev config --project-type=${MAGENTO_PROJECT_TYPE} --docroot="${docroot}" --project-name=${PROJECT_NAME} \
    --upload-dirs=media --disable-settings-management \
    --php-version=${php_version} --database=${MAGENTO_DATABASE} \
    --nodejs-version=$(ddev_nodejs_version) || exit 1 ;
  magento_add_search || exit 1 ;
  ddev_up start -y || exit 1 ;

  magento_step "The code: Magento Open Source ${version} from ${MAGENTO_MIRROR}" ;
  magento_retry magento_download "${version}" \
    || { echo "Magento Open Source ${version} could not be downloaded from ${MAGENTO_MIRROR}: a version that does not exist, or no network in the container." ; exit 1 ; } ;

  if [ "${INSTALL}" == 'yes' ] ; then
    magento_step "The store" ;
    # The container's own database values, the same in every project: nothing personal is written.
    ddev exec "${MAGENTO_CONSOLE} setup:install \
      --disable-modules='${MAGENTO_DISABLED_MODULES}' \
      --base-url='${base_url}/' --base-url-secure='${base_url}/' --use-secure=1 --use-secure-admin=1 --use-rewrites=1 \
      --db-host=db --db-name=db --db-user=db --db-password=db \
      --search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 \
      --opensearch-index-prefix=magento2 --opensearch-enable-auth=0 --opensearch-timeout=15 \
      --backend-frontname='${MAGENTO_ADMIN_PATH}' \
      --admin-user=$(printf '%q' "${account_name}") --admin-password=$(printf '%q' "${account_pass}") \
      --admin-email=$(printf '%q' "${account_mail}") --admin-firstname=Workspace --admin-lastname=Owner \
      --language=en_US --currency=USD --timezone=UTC \
      --session-save=files --cleanup-database --no-interaction" \
      || { echo "The Magento installer failed." ; exit 1 ; } ;

    if [ ! "${SAMPLE_DATA}" == 'no' ] ; then
      magento_step "The sample catalog" ;
      magento_retry ddev exec "${MAGENTO_CONSOLE} sampledata:deploy --no-interaction" \
        || { echo "The sample catalog could not be downloaded from ${MAGENTO_MIRROR}." ; exit 1 ; } ;
    fi
    ddev exec "${MAGENTO_CONSOLE} setup:upgrade --no-interaction" || { echo "setup:upgrade failed." ; exit 1 ; } ;

    magento_step "The settings of a local store" ;
    magento_local_settings || { echo "The settings of the store could not be written." ; exit 1 ; } ;

    if [ "${ADD_USERS}" == 'yes' ] ; then
      magento_step "The default accounts" ;
      set_magento_users ;
      add_magento_users ;
      cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
    fi

    magento_step "Production mode: the code compiled, the static content deployed" ;
    magento_set_mode production || { echo "The store could not be put into production mode." ; exit 1 ; } ;

    magento_step "The indexes, cron once, the cache" ;
    # The indexes update when something is saved, not by a schedule: no cron is left running on a
    # local store, and a product that is saved reaches the storefront at once.
    ddev exec "${MAGENTO_CONSOLE} indexer:set-mode realtime && ${MAGENTO_CONSOLE} indexer:reindex" ;
    ddev exec "${MAGENTO_CONSOLE} cron:run" || true ;
    ddev exec "${MAGENTO_CONSOLE} cache:flush" ;
    # The first request of each side builds its cache: make it here, not in front of a person.
    ddev exec "curl -ksL -o /dev/null '${base_url}/' ; curl -ksL -o /dev/null '${base_url}/${MAGENTO_ADMIN_PATH}/'" ;

    echo "" ;
    echo "${doc_name} ${PROJECT_NAME} has been installed in $(( ($(date +%s) - started) / 60 )) minutes: $(magento_console --version 2>/dev/null | head -1).";
    echo "Go to ${base_url}/${MAGENTO_ADMIN_PATH} and log in as ${account_name}";
  else
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: there is no store to add accounts to yet." ;
    echo "${doc_name} ${PROJECT_NAME} has the code of Magento Open Source ${version}, and is not installed.";
    echo "The edition has no installer in the browser: build again with --install, or run setup:install with cmd-tools-magento-cli.sh ${PROJECT_NAME} --run.";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Add, delete or list accounts of the store, in its container, through the store's own classes:
# the command line makes an administrator and no other account. $1 is add, cancel or list; the
# accounts are the list the caller loaded (set_magento_users). An admin user gets its role by the
# role's name, and the Sales role is made when the store does not have it; a customer gets one
# address, its default for billing and shipping. Run twice, it leaves an account that exists as it is.
function magento_accounts() {
  local action="$1" rows='' user field value ;
  for user in "${users[@]}" ; do
    for field in kind name mail password firstname lastname role street city region postcode phone ; do
      value="user_${user}_${field}" ;
      rows="${rows}${!value}|" ;
    done
    rows="${rows%|};" ;
  done
  ddev exec "MAGENTO_ACCOUNTS=$(printf '%q' "${rows}") php -- ${action}" <<'ACCOUNTSEOF'
<?php
// Runs in the root of the store. The accounts arrive in MAGENTO_ACCOUNTS, one per ";":
// kind|user name|e-mail|password|first name|last name|role|street|city|region|postcode|phone.
use Magento\Framework\App\Bootstrap;
use Magento\Framework\Exception\NoSuchEntityException;

require getcwd() . '/app/bootstrap.php';

$om = Bootstrap::create(BP, $_SERVER)->getObjectManager();
$om->get(\Magento\Framework\App\State::class)->setAreaCode('adminhtml');
$action = $argv[1] ?? 'list';

$storeManager = $om->get(\Magento\Store\Model\StoreManagerInterface::class);
$websiteId = (int) $storeManager->getDefaultStoreView()->getWebsiteId();
$storeId = (int) $storeManager->getDefaultStoreView()->getId();
$customerRepository = $om->get(\Magento\Customer\Api\CustomerRepositoryInterface::class);

$roleByName = static function (string $name) use ($om) {
    $roles = $om->create(\Magento\Authorization\Model\ResourceModel\Role\CollectionFactory::class)->create();
    return $roles->addFieldToFilter('role_name', $name)->addFieldToFilter('role_type', 'G')->getFirstItem();
};

if ($action === 'list') {
    echo "Admin users (the admin panel):\n";
    foreach ($om->create(\Magento\User\Model\ResourceModel\User\CollectionFactory::class)->create() as $user) {
        printf("  %-18s %-30s %-22s %s%s\n", $user->getUserName(), $user->getEmail(), $user->getFirstName() . ' ' . $user->getLastName(),
            $user->getRole()->getRoleName(), $user->getIsActive() ? '' : ' (disabled)');
    }
    echo "Customers (the store):\n";
    foreach ($om->create(\Magento\Customer\Model\ResourceModel\Customer\CollectionFactory::class)->create() as $customer) {
        printf("  %-30s %s\n", $customer->getEmail(), $customer->getFirstname() . ' ' . $customer->getLastname());
    }
    exit(0);
}

// A role limited to Sales: orders, invoices, shipments and credit memos, and nothing else.
$salesResources = [
    'Magento_Backend::admin', 'Magento_Sales::sales', 'Magento_Sales::sales_operation', 'Magento_Sales::sales_order',
    'Magento_Sales::actions', 'Magento_Sales::create', 'Magento_Sales::actions_view', 'Magento_Sales::email',
    'Magento_Sales::reorder', 'Magento_Sales::actions_edit', 'Magento_Sales::cancel', 'Magento_Sales::review_payment',
    'Magento_Sales::capture', 'Magento_Sales::invoice', 'Magento_Sales::creditmemo', 'Magento_Sales::hold',
    'Magento_Sales::unhold', 'Magento_Sales::ship', 'Magento_Sales::comment', 'Magento_Sales::emails',
    'Magento_Sales::sales_invoice', 'Magento_Sales::shipment', 'Magento_Sales::sales_creditmemo',
];

$failed = 0;
foreach (array_filter(explode(';', (string) getenv('MAGENTO_ACCOUNTS'))) as $row) {
    [$kind, $username, $email, $password, $first, $last, $roleName, $street, $city, $regionCode, $postcode, $phone] = array_pad(explode('|', $row), 12, '');
    try {
        if ($kind === 'admin') {
            $user = $om->create(\Magento\User\Model\UserFactory::class)->create()->loadByUsername($username);
            if ($action === 'cancel') {
                if (!$user->getId()) {
                    echo "   $username is not there.\n";
                } else {
                    $user->delete();
                    echo "   $username is deleted.\n";
                }
                continue;
            }
            if ($user->getId()) {
                echo "   $username is already there.\n";
                continue;
            }
            $role = $roleByName($roleName);
            if (!$role->getId() && $roleName === 'Sales') {
                $role = $om->create(\Magento\Authorization\Model\RoleFactory::class)->create();
                $role->setRoleName($roleName)->setParentId(0)->setRoleType('G')->setUserType(2)->save();
                $om->create(\Magento\Authorization\Model\RulesFactory::class)->create()
                    ->setRoleId($role->getId())->setResources($salesResources)->saveRel();
                echo "   the role \"$roleName\" is made: Sales and nothing else.\n";
            }
            if (!$role->getId()) {
                echo "   $username: the store has no role \"$roleName\".\n";
                ++$failed;
                continue;
            }
            $user->setData([
                'username' => $username, 'firstname' => $first, 'lastname' => $last, 'email' => $email,
                'password' => $password, 'interface_locale' => 'en_US', 'is_active' => 1,
            ]);
            $user->setRoleId($role->getId())->save();
            echo "   $username is an admin user with the role \"$roleName\".\n";
            continue;
        }

        try {
            $found = $customerRepository->get($email, $websiteId);
        } catch (NoSuchEntityException $e) {
            $found = null;
        }
        if ($action === 'cancel') {
            if (!$found) {
                echo "   $email is not there.\n";
            } else {
                // The store deletes a customer only in what it calls a secure area.
                $registry = $om->get(\Magento\Framework\Registry::class);
                $registry->unregister('isSecureArea');
                $registry->register('isSecureArea', true);
                $customerRepository->deleteById($found->getId());
                echo "   $email is deleted.\n";
            }
            continue;
        }
        if ($found) {
            echo "   $email is already there.\n";
            continue;
        }
        $region = $om->get(\Magento\Directory\Model\RegionFactory::class)->create()->loadByCode($regionCode, 'US');
        $address = $om->get(\Magento\Customer\Api\Data\AddressInterfaceFactory::class)->create()
            ->setFirstname($first)->setLastname($last)
            ->setStreet([$street])->setCity($city)->setPostcode($postcode)
            ->setCountryId('US')->setTelephone($phone)
            ->setRegionId((int) $region->getId())
            ->setRegion($om->get(\Magento\Customer\Api\Data\RegionInterfaceFactory::class)->create()
                ->setRegionId((int) $region->getId())->setRegion($region->getName())->setRegionCode($regionCode))
            ->setIsDefaultBilling(true)->setIsDefaultShipping(true);
        $customer = $om->get(\Magento\Customer\Api\Data\CustomerInterfaceFactory::class)->create()
            ->setEmail($email)->setFirstname($first)->setLastname($last)
            ->setWebsiteId($websiteId)->setStoreId($storeId)->setGroupId(1)
            ->setAddresses([$address]);
        $om->get(\Magento\Customer\Api\AccountManagementInterface::class)->createAccount($customer, $password);
        echo "   $email is a customer with an address.\n";
    } catch (\Throwable $e) {
        echo '   ' . ($kind === 'admin' ? $username : $email) . ': ' . $e->getMessage() . "\n";
        ++$failed;
    }
}
exit($failed ? 1 : 0);
ACCOUNTSEOF
}

# Create the default accounts in the store. An account that is already there is left as it is.
# The list is loaded by the caller (set_magento_users): the core's add_users, the builder, the CLI tool.
function add_magento_users() {
  magento_enter_project || return 1 ;
  local user user_name user_mail user_password user_role status ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";
  done
  magento_accounts add ; status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts. The Sales role stays: it is a role of the store, not an account.
function cancel_magento_users() {
  magento_enter_project || return 1 ;
  local user user_name user_mail status ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo " ================================================================= ";
  done
  magento_accounts cancel ; status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# The same three under the name of the DDEV project type: the Users menu of a project row reads
# the type of the project (magento2) and asks for the list of that name.
function set_magento2_users() { set_magento_users ; }
function add_magento2_users() { add_magento_users ; }
function cancel_magento2_users() { cancel_magento_users ; }

# What cmd-tools-magento-cli.sh does: the first of --run, --flush-cache, --reindex, --mode,
# --add-users, --cancel-users that was asked for; with none of them, what the store is.
function magento_cli_tool() {
  trim_project_name ;
  magento_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN:-_none_}" == '_none_' ] ; then
    # One string on purpose: --run "module:status Magento_Sales" is a command and its arguments.
    ddev exec "${MAGENTO_CONSOLE} ${RUN}" ;
    exit $? ;
  fi

  if [ "${FLUSH_CACHE}" == 'yes' ] ; then
    magento_console cache:flush ;
  elif [ "${REINDEX}" == 'yes' ] ; then
    magento_console indexer:reindex ;
  elif [ ! "${MODE:-_none_}" == '_none_' ] ; then
    magento_set_mode "${MODE}" && magento_console cache:flush ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_magento_users ;
    add_magento_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_magento_users ;
    cancel_magento_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}: $(magento_console --version 2>/dev/null | head -1) at https://${PROJECT_NAME}.ddev.site" ;
    if magento_is_installed "$(pwd)" ; then
      echo "The admin panel: https://${PROJECT_NAME}.ddev.site/$(magento_admin_path "$(pwd)")" ;
      magento_console deploy:mode:show ;
      echo "" ; users=() ; magento_accounts list ;
    else
      echo "The store is not installed yet: build it again with --install." ;
    fi
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a store. The core's testing_configure calls this in the
# project folder once webship-js is scaffolded and before the dependencies are installed; for a
# project that is not a store it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's
# own, and gives cucumber.js what the pack reads: the path of the admin panel, the command that
# rebuilds the indexes (run where the suite runs, in the container of the project) and the users
# registry of the default accounts (a handle a scenario reads, mapped to an account; never the
# workspace account). It tells Firefox not to react to a change of network, for a run on a machine
# where other projects start and stop, and writes a first feature when the project has none of its
# own. Every part is skipped when it is already there, so a second run adds what the first missed
# and never resets a suite.
function testing_configure_magento() {
  local project_path="$1";
  magento_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Magento: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Magento step pack (${MAGENTO_STEPS_PACKAGE} ${MAGENTO_STEPS_VERSION}).";
  set_magento_users ;
  local registry="" user handle user_name user_mail user_password user_kind user_firstname user_lastname ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    user_kind="user_${user}_kind"; user_firstname="user_${user}_firstname"; user_lastname="user_${user}_lastname";
    # The pack's features call the admin user with every right "admin".
    handle="${user}" ; [ "${user}" == 'administrator' ] && handle="admin" ;
    registry="${registry}${!user_kind}|${handle}|${!user_name}|${!user_mail}|${!user_password}|${!user_firstname} ${!user_lastname}"$'\n' ;
  done

  python3 - "${project_path}" "${MAGENTO_STEPS_PACKAGE}" "${MAGENTO_STEPS_VERSION}" 'STORE' "${registry}" "$(magento_admin_path "${project_path}")" "${MAGENTO_CONSOLE} indexer:reindex" <<'PYEOF' || return 1
import json, os, re, sys

project, pack, version, prefix, registry, admin_path, reindex = sys.argv[1:8]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=2) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, then what the pack reads.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
block, said = [], []
if world:
    pad = world.group(1) + '  '
    if not re.search(r"^[ \t]*adminPath:", src, re.M):
        block += [
            pad + "// The first path segment of the admin panel: the builder pins it. ADMIN_PATH names another one.",
            pad + "adminPath: process.env.ADMIN_PATH || '%s'," % admin_path,
        ]
        said.append('the admin path (%s)' % admin_path)
    if not re.search(r"^[ \t]*reindexCommand:", src, re.M):
        block += [
            pad + "// How a scenario rebuilds the indexes (`When I rebuild the invalid indexes`): the admin panel has no button",
            pad + "// for it. The suite runs in the container of the project, so the command is the store's own, in its root.",
            pad + "reindexCommand: process.env.REINDEX_COMMAND || '%s'," % reindex,
            pad + "siteDir: process.env.SITE_DIR || '.',",
        ]
        said.append('the reindex command')
    if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
        rows = [r.split('|') for r in registry.splitlines() if r.strip()]
        block += [
            pad + "// The users registry: a handle a scenario reads, mapped to an account of this store (the default accounts:",
            pad + "// cmd-tools-add-users.sh). An admin user carries `username`, a customer carries `email` and the name the store",
            pad + "// greets it by. Override one with %s_<HANDLE>_USER (or _EMAIL) and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
            pad + "users: {",
        ]
        for kind, handle, name, mail, password, full in rows:
            env = '%s_%s' % (prefix, handle.upper())
            if kind == 'admin':
                block.append(pad + "  %s: { username: process.env.%s_USER || '%s', password: process.env.%s_PASSWORD || '%s' }," % (handle, env, name, env, password))
            else:
                block.append(pad + "  %s: { email: process.env.%s_EMAIL || '%s', password: process.env.%s_PASSWORD || '%s', name: '%s' }," % (handle, env, mail, env, password, full))
        block.append(pad + "},")
        said.append('the users registry (%s)' % ', '.join(r[1] for r in rows))
    if block:
        src = src[:world.end()] + '\n' + '\n'.join(block) + src[world.end():]
        print('  cucumber.js: ' + ', '.join(said))
elif not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    sys.exit("  cucumber.js has no worldParameters block to add the admin path and the users registry to.")

if src != before:
    open(cucumber_file, 'w').write(src)

# playwright.config.ts: Chromium aborts every request in flight when a container network comes or
# goes on the machine; Firefox can be told not to react. Nothing changes for the other browsers.
config_file = project + '/playwright.config.ts'
if os.path.isfile(config_file):
    config = open(config_file).read()
    if 'firefoxUserPrefs' not in config:
        args = re.search(r"^([ \t]*)args:[ \t]*browser === 'chromium' \? chromiumArgs : \[\],[ \t]*$", config, re.M)
        if args:
            pad = args.group(1)
            lines = [
                pad + "// On a machine where other projects start and stop, Chromium aborts every request in flight",
                pad + "// (net::ERR_NETWORK_CHANGED). Firefox is told not to react to a change of network: --browser firefox.",
                pad + "...(browser === 'firefox' ? { firefoxUserPrefs: { 'network.notify.changed': false } } : {}),",
            ]
            config = config[:args.end()] + '\n' + '\n'.join(lines) + config[args.end():]
            open(config_file, 'w').write(config)
            print('  playwright.config.ts: Firefox does not react to a change of network')
PYEOF

  # A first feature, when the project has none for the store yet: the front page, the admin panel,
  # each default account on its side.
  local feature="${WORKSPACE_SCRIPTS}/plugins/magento/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the store" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed store has them.
  if magento_is_installed "${project_path}" ; then
    ( add_magento_users > /dev/null ) && echo "  the default accounts are in the store (${users[*]})" ;
  fi
}
