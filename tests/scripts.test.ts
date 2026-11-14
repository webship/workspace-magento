import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-magento.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

// The playwright.config.ts webship-js scaffolds, as far as the testing hook reads it.
const PLAYWRIGHT = `const browser = (process.env.BROWSER || 'chromium');
const chromiumArgs: string[] = ['--no-sandbox'];
const config = {
  browser,
  launchOptions: {
    headless: process.env.HEADLESS !== 'false',
    args: browser === 'chromium' ? chromiumArgs : [],
  },
};
export = config;
`;

// The add-on's compose file, as far as the builder rewrites it.
const COMPOSE = `#ddev-generated
services:
  opensearch:
    container_name: ddev-\${DDEV_SITENAME}-opensearch
    environment:
      - "DISABLE_SECURITY_PLUGIN=true"
      - discovery.type=single-node
      - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"
      - VIRTUAL_HOST=$DDEV_HOSTNAME
      - HTTP_EXPOSE=9200:9200
      - HTTPS_EXPOSE=9201:9200
    volumes:
      - opensearch:/usr/share/opensearch/data

  opensearch-dashboards:
    image: opensearchproject/opensearch-dashboards:latest
    environment:
      - VIRTUAL_HOST=$DDEV_HOSTNAME
      - HTTP_EXPOSE=5601:5601
    depends_on:
      - opensearch

  web:
    depends_on:
      - opensearch

volumes:
  opensearch:
`;

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(kind: 'magento' | 'other', installed = true) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'magento-plugin-'));
  const dir = path.join(root, 'dev', 'store1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: store1\ntype: ${kind === 'magento' ? 'magento2' : 'drupal11'}\ndocroot: pub\n`);
  if (kind === 'magento' && installed) {
    // What the installer of the store writes.
    fs.mkdirSync(path.join(dir, 'app', 'etc'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'app', 'etc', 'env.php'), "<?php\nreturn [\n    'backend' => [\n        'frontName' => 'admin'\n    ],\n];\n");
    fs.writeFileSync(path.join(dir, 'app', 'etc', 'config.php'), '<?php\nreturn [];\n');
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'playwright.config.ts'), PLAYWRIGHT);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'store1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'magento'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'magento', 'site.feature'));
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced, `ddev` replaced by a recorder (it also swallows what a command is fed) and the
 * general helpers of the workspace replaced by recorders too. DDEV_FAIL names a pattern of calls that fail.
 */
function bash(script: string, env: Record<string, string> = {}) {
  const stubs = [
    'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; [ -t 0 ] || cat > /dev/null ; [ -n "${DDEV_FAIL:-}" ] && [[ "$*" =~ ${DDEV_FAIL} ]] && return 1 ; return 0 ; }',
    'trim_project_name() { :; }',
    'drop_database() { echo "drop_database ${PROJECT_NAME}" >> "${DDEV_LOG:-/dev/null}" ; }',
    'ddev_up() { ddev "$@" ; }',
    'ddev_nodejs_version() { echo 24 ; }',
    'sleep() { :; }',
  ].join('\n');
  return spawnSync('bash', ['-c', `${stubs}\nsource ${FUNCTIONS}\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
}

test('the default accounts are an administrator, an admin user limited to Sales and two customers with an address, with example addresses', () => {
  const r = bash('set_magento_users ; for u in "${users[@]}" ; do for f in name mail password role kind street ; do v="user_${u}_${f}" ; printf "%s|" "${!v}" ; done ; echo ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'sales', 'customer', 'shopper']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['Administrators', 'Sales', 'Customer', 'Customer']);
  assert.deepStrictEqual(rows.map((x) => x[4]), ['admin', 'admin', 'customer', 'customer']);
  assert.deepStrictEqual(rows.map((x) => x[5]), ['', '', '100 Main Street', '200 Market Street'], 'a customer has an address');
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`, 'a test account of its own, never the workspace account');
    assert.ok(password.length >= 8 && /[a-z]/.test(password) && /[A-Z]/.test(password) && /[0-9]/.test(password), 'a password the store accepts for an admin user and for a customer');
  }
});

test('the list is the same under the name of the project type, which is what the Users menu of a row asks for', () => {
  const r = bash('set_magento2_users ; echo "${users[*]}" ; echo "${user_sales_role}"');
  assert.strictEqual(r.stdout.trim(), 'administrator sales customer shopper\nSales');
  const p = project('magento');
  const log = path.join(p.root, 'ddev.log');
  const added = bash('set_magento2_users ; add_magento2_users', { WORKSPACE_ROOT: p.root, doc_name: 'dev', PROJECT_NAME: 'store1', DDEV_LOG: log });
  assert.strictEqual(added.status, 0, added.stderr);
  assert.match(fs.readFileSync(log, 'utf8'), /ddev exec MAGENTO_ACCOUNTS=admin\\\|administrator\\\|administrator@example\.com[^\n]+ php -- add/);
  const cancelled = bash('set_magento2_users ; cancel_magento2_users', { WORKSPACE_ROOT: p.root, doc_name: 'dev', PROJECT_NAME: 'store1', DDEV_LOG: log });
  assert.strictEqual(cancelled.status, 0, cancelled.stderr);
  assert.match(fs.readFileSync(log, 'utf8'), /php -- cancel/);
});

test('the testing hook adds the step pack, what the pack reads, the Firefox setting and a first feature to a store, once', () => {
  const p = project('magento');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_magento ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'store1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/magento-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/magento-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /adminPath: process\.env\.ADMIN_PATH \|\| 'admin',/);
  assert.match(cucumber, /reindexCommand: process\.env\.REINDEX_COMMAND \|\| 'php bin\/magento indexer:reindex',/, 'the suite runs in the container: the command is the store\'s own');
  assert.match(cucumber, /siteDir: process\.env\.SITE_DIR \|\| '\.',/);
  assert.match(cucumber, /admin: \{ username: process\.env\.STORE_ADMIN_USER \|\| 'administrator', password: process\.env\.STORE_ADMIN_PASSWORD \|\| '[^']+' \},/);
  assert.match(cucumber, /sales: \{ username: process\.env\.STORE_SALES_USER \|\| 'sales', password: process\.env\.STORE_SALES_PASSWORD \|\| '[^']+' \},/);
  assert.match(cucumber, /customer: \{ email: process\.env\.STORE_CUSTOMER_EMAIL \|\| 'customer@example\.com', password: process\.env\.STORE_CUSTOMER_PASSWORD \|\| '[^']+', name: 'Casey Customer' \},/);
  assert.match(cucumber, /shopper: \{ email: process\.env\.STORE_SHOPPER_EMAIL \|\| 'shopper@example\.com', password: process\.env\.STORE_SHOPPER_PASSWORD \|\| '[^']+', name: 'Sam Shopper' \},/);
  // Still a module node can load, with everything where the pack reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; const w = c.worldParameters; console.log(JSON.stringify([c.require, Object.keys(w.users), w.adminPath, w.reindexCommand, w.siteDir, w.launchUrl]))`], { encoding: 'utf8' });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, adminPath, reindex, siteDir, launchUrl] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['admin', 'sales', 'customer', 'shopper'], 'the handles the pack logs in as');
  assert.deepStrictEqual([adminPath, reindex, siteDir], ['admin', 'php bin/magento indexer:reindex', '.']);
  assert.strictEqual(launchUrl, 'http://localhost:8080', 'what the scaffold set stays');
  assert.doesNotMatch(cucumber, /webmaster|account_/, 'the workspace account is in no registry');
  const playwright = fs.readFileSync(path.join(p.dir, 'playwright.config.ts'), 'utf8');
  assert.match(playwright, /args: browser === 'chromium' \? chromiumArgs : \[\],\n(\s+\/\/.*\n)+\s+\.\.\.\(browser === 'firefox' \? \{ firefoxUserPrefs: \{ 'network\.notify\.changed': false \} \} : \{\}\),/, 'Firefox is told not to react to a change of network');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /ddev exec MAGENTO_ACCOUNTS=admin\\\|administrator\\\|administrator@example\.com\\\|\S+\\\|Store\\\|Admin\\\|Administrators\\\|\\\|\\\|\\\|\\\|\\;admin\\\|sales\\\|sales@example\.com\\\|\S+\\\|Sally\\\|Sales\\\|Sales[^\n]+customer\\\|customer\\\|customer@example\.com[^\n]+100\\ Main\\ Street\\\|Austin\\\|TX\\\|78701[^\n]+ php -- add/, 'an installed store gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'playwright.config.ts'), 'utf8'), playwright);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8').split('@webship-js/magento-steps').length - 1, 1);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook reads the admin path from the project, and keeps a registry the project already has', () => {
  const p = project('magento');
  fs.writeFileSync(path.join(p.dir, 'app', 'etc', 'env.php'), "<?php\nreturn [\n    'backend' => [\n        'frontName' => 'backoffice_x1'\n    ],\n];\n");
  fs.writeFileSync(path.join(p.dir, 'cucumber.js'), SCAFFOLD.replace("    worldParameters: {\n", "    worldParameters: {\n      users: {\n        owner: { username: 'owner', password: 'x' },\n      },\n"));
  const r = bash(`cd ${p.dir} && testing_configure_magento ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'store1' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  assert.match(cucumber, /ADMIN_PATH \|\| 'backoffice_x1'/);
  assert.match(cucumber, /owner: \{ username: 'owner'/);
  assert.doesNotMatch(cucumber, /STORE_ADMIN_USER/, 'a registry that is there is the project\'s own');
});

test('the testing hook adds no account to a store that is not installed', () => {
  const p = project('magento', false);
  const log = path.join(p.root, 'ddev.log');
  const r = bash(`cd ${p.dir} && testing_configure_magento ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'store1', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.ok(!fs.existsSync(log), 'the container was not asked for anything');
  assert.match(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), /ADMIN_PATH \|\| 'admin'/, 'the pinned path when there is none to read');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('other');
  const r = bash(`cd ${p.dir} && testing_configure_magento ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'store1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'playwright.config.ts'), 'utf8'), PLAYWRIGHT);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the command-line tool refuses a project that is not a store', () => {
  const p = project('other');
  const r = bash('PROJECT_NAME=store1 ; RUN="list" ; magento_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Magento Open Source project/);
});

test('the command-line tool runs a command, flushes the cache, rebuilds the indexes, changes the mode and cancels the accounts', () => {
  const p = project('magento');
  const log = path.join(p.root, 'ddev.log');
  const tool = (vars: string) => bash(`PROJECT_NAME=store1 ; RUN=_none_ ; MODE=_none_ ; ${vars} ; magento_cli_tool`, { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log });
  const calls = () => fs.readFileSync(log, 'utf8');
  assert.strictEqual(tool('RUN="module:status Magento_Sales"').status, 0);
  assert.match(calls(), /^ddev exec php bin\/magento module:status Magento_Sales$/m);
  assert.strictEqual(tool('FLUSH_CACHE=yes').status, 0);
  assert.match(calls(), /^ddev exec php bin\/magento cache:flush$/m);
  assert.strictEqual(tool('REINDEX=yes').status, 0);
  assert.match(calls(), /^ddev exec php bin\/magento indexer:reindex$/m);
  fs.writeFileSync(log, '');
  assert.strictEqual(tool('MODE=production').status, 0);
  assert.match(calls(), /deploy:mode:set production --skip-compilation\s+&& php -d memory_limit=2G bin\/magento setup:di:compile\s+&& php -d memory_limit=2G bin\/magento setup:static-content:deploy -f --jobs=2 en_US\nddev exec php bin\/magento cache:flush/);
  assert.strictEqual(tool('MODE=developer').status, 0);
  assert.match(calls(), /^ddev exec php bin\/magento deploy:mode:set developer$/m);
  const r = tool('CANCEL_USERS=yes');
  assert.strictEqual(r.status, 0, r.stderr);
  assert.match(r.stdout, /User name: administrator/);
  assert.match(r.stdout, /User mail: shopper@example\.com/);
  assert.match(calls(), /MAGENTO_ACCOUNTS=[^\n]+ php -- cancel/);
  fs.writeFileSync(log, '');
  const status = tool(':');
  assert.strictEqual(status.status, 0, status.stderr);
  assert.match(status.stdout, /The admin panel: https:\/\/store1\.ddev\.site\/admin/);
  assert.match(calls(), /deploy:mode:show[\s\S]*MAGENTO_ACCOUNTS=\S* php -- list/);
});

test('--install is refused before anything is built when the workspace password does not pass the store\'s rule', () => {
  for (const pass of ['short1', 'lettersonly', '1234567890']) {
    const p = project('other');
    const log = path.join(p.root, 'ddev.log');
    const r = bash(`PROJECT_NAME=store2 ; INSTALL=yes ; account_pass=${pass} ; magento_build`, { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log });
    assert.strictEqual(r.status, 1, pass);
    assert.match(r.stdout, /7 characters or more with both letters and digits/);
    assert.ok(!fs.existsSync(log), 'nothing was dropped and the container tool was not called');
    assert.ok(!fs.existsSync(path.join(p.root, 'dev', 'store2')));
  }
});

test('a version that is not a 2.4 release is refused before anything is built', () => {
  for (const version of ['latest', '2.3.7', '2.5.0', '2.4', '2.4.9; rm -rf x']) {
    const p = project('other');
    const log = path.join(p.root, 'ddev.log');
    const r = bash('PROJECT_NAME=store2 ; magento_build', { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log, VERSION: version });
    assert.strictEqual(r.status, 1, version);
    assert.match(r.stdout, /Magento Open Source 2\.4 store/);
    assert.ok(!fs.existsSync(log), 'the container tool was not called');
  }
});

test('a build is refused when the machine has less memory available than a store uses', () => {
  const p = project('other');
  const log = path.join(p.root, 'ddev.log');
  const meminfo = path.join(p.root, 'meminfo');
  fs.writeFileSync(meminfo, 'MemTotal:       16000000 kB\nMemAvailable:    1500000 kB\n');
  const r = bash('PROJECT_NAME=store2 ; magento_build', { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log, MAGENTO_MEMINFO: meminfo });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /about 2 GB of memory, and this machine has 1464 MB available/);
  assert.ok(!fs.existsSync(log), 'the container tool was not called');
});

test('a build configures the container, adds the search engine, downloads from the mirror, installs with the workspace account and adds the accounts', () => {
  const p = project('other');
  const log = path.join(p.root, 'ddev.log');
  const meminfo = path.join(p.root, 'meminfo');
  fs.writeFileSync(meminfo, 'MemAvailable:    8000000 kB\n');
  // The add-on, as the container tool would have placed it.
  const addon = `ddev() { echo "ddev $*" >> "$DDEV_LOG" ; [ -t 0 ] || cat > /dev/null ; if [ "$1 $2" == "add-on get" ] ; then cat > .ddev/docker-compose.opensearch.yaml <<'COMPOSE'\n${COMPOSE}COMPOSE\n fi ; [ "$1" == "config" ] && mkdir -p .ddev && printf 'type: magento2\\n' > .ddev/config.yaml ; return 0 ; }`;
  const r = bash(`${addon}\nPROJECT_NAME=store2 ; INSTALL=yes ; ADD_USERS=yes ; SAMPLE_DATA=yes ; account_name=webmaster ; account_pass='dD.123 123' ; account_mail=webmaster@example.com ; distribution_webroot=pub ; magento_build`,
    { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log, MAGENTO_MEMINFO: meminfo });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const calls = fs.readFileSync(log, 'utf8');
  const order = ['drop_database store2', 'ddev config --project-type=magento2 --docroot=pub --project-name=store2 --upload-dirs=media --disable-settings-management --php-version=8.4 --database=mariadb:11.4 --nodejs-version=24',
    'ddev add-on get ddev/ddev-opensearch', 'ddev start -y', "composer create-project --repository-url='https://mirror.mage-os.org/' 'magento/project-community-edition:2.4.9' /tmp/magento-project --no-interaction --prefer-dist --no-install", 'ddev composer install --no-interaction --prefer-dist',
    'setup:install', 'sampledata:deploy --no-interaction', 'setup:upgrade --no-interaction', "config:set -q 'admin/security/use_form_key' '0'", 'php -- add', 'deploy:mode:set production', 'indexer:set-mode realtime', 'cron:run', 'cache:flush'];
  let at = -1;
  for (const part of order) {
    const next = calls.indexOf(part, at + 1);
    assert.ok(next > at, `${part} comes in its turn`);
    at = next;
  }
  assert.match(calls, /--base-url='https:\/\/store2\.ddev\.site\/' --base-url-secure='https:\/\/store2\.ddev\.site\/'/);
  assert.match(calls, /--admin-user=webmaster --admin-password=dD\.123\\ 123\s+--admin-email=webmaster@example\.com/, 'the administrator is the workspace account, quoted for the container\'s shell');
  assert.match(r.stdout, /log in as webmaster/);
  assert.doesNotMatch(r.stdout, /dD\.123 123/, 'the password of the workspace account is not printed');
  // The search engine: its tag, and the compose file with the engine only.
  const ddevDir = path.join(p.root, 'dev', 'store2', '.ddev');
  assert.strictEqual(fs.readFileSync(path.join(ddevDir, '.env.opensearch'), 'utf8'), 'OPENSEARCH_TAG=3\n');
  const compose = fs.readFileSync(path.join(ddevDir, 'docker-compose.opensearch.yaml'), 'utf8');
  assert.doesNotMatch(compose, /opensearch-dashboards/, 'the dashboards service is taken out');
  assert.doesNotMatch(compose, /#ddev-generated|VIRTUAL_HOST|HTTP_EXPOSE|HTTPS_EXPOSE/, 'the engine is not published through the shared router, and the file is the project\'s own now');
  assert.match(compose, /- "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"/, 'the heap is limited');
  assert.match(compose, /\n  web:\n    depends_on:\n      - opensearch\n\nvolumes:\n  opensearch:\n$/, 'the rest stays');
});

test('a build without the sample catalog and without the accounts asks for neither, and one without --install stops at the code', () => {
  const p = project('other');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log, MAGENTO_MEMINFO: '/nonexistent' };
  const addon = 'ddev() { echo "ddev $*" >> "$DDEV_LOG" ; [ -t 0 ] || cat > /dev/null ; [ "$1" == "config" ] && mkdir -p .ddev && touch .ddev/docker-compose.opensearch.yaml ; return 0 ; }';
  const bare = bash(`${addon}\nPROJECT_NAME=store2 ; INSTALL=yes ; SAMPLE_DATA=no ; account_name=webmaster ; account_pass=dD.123123ddd ; account_mail=webmaster@example.com ; magento_build`, env);
  assert.strictEqual(bare.status, 0, bare.stderr + bare.stdout);
  assert.match(fs.readFileSync(log, 'utf8'), /setup:install/);
  assert.doesNotMatch(fs.readFileSync(log, 'utf8'), /sampledata:deploy|php -- add|add-on get/, 'no sample catalog, no accounts, and an add-on that is there is not fetched again');
  fs.writeFileSync(log, '');
  const code = bash(`${addon}\nPROJECT_NAME=store2 ; ADD_USERS=yes ; VERSION=2.4.8-p3 ; PHP_VERSION=8.3 ; magento_build`, env);
  assert.strictEqual(code.status, 0, code.stderr + code.stdout);
  assert.match(fs.readFileSync(log, 'utf8'), /--php-version=8\.3 [\s\S]*'magento\/project-community-edition:2\.4\.8-p3' /);
  assert.doesNotMatch(fs.readFileSync(log, 'utf8'), /setup:install|php -- add/);
  assert.match(code.stdout, /--add-users needs --install/);
  assert.match(code.stdout, /has no installer in the browser/);
});

test('a download that fails is tried three times, and then the build stops and says so', () => {
  const p = project('other');
  const log = path.join(p.root, 'ddev.log');
  const addon = 'ddev() { echo "ddev $*" >> "$DDEV_LOG" ; [ "$1" == "config" ] && mkdir -p .ddev && touch .ddev/docker-compose.opensearch.yaml ; [[ "$*" =~ ${DDEV_FAIL} ]] && return 1 ; return 0 ; }';
  const r = bash(`${addon}\nPROJECT_NAME=store2 ; magento_build`, { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log, MAGENTO_MEMINFO: '/nonexistent', DDEV_FAIL: '^composer install' });
  assert.strictEqual(r.status, 1);
  assert.strictEqual(fs.readFileSync(log, 'utf8').split('ddev composer install').length - 1, 3);
  assert.strictEqual(fs.readFileSync(log, 'utf8').split('rm -rf /tmp/magento-project && composer create-project').length - 1, 3, 'each try starts from a clean copy of the project');
  assert.match(r.stdout, /try 2 of 3/);
  assert.match(r.stdout, /could not be downloaded from https:\/\/mirror\.mage-os\.org\//);
  assert.doesNotMatch(fs.readFileSync(log, 'utf8'), /setup:install/);
});

test('an older container tool gets the search add-on from a clone without its version constraint', () => {
  const p = project('other');
  const dir = path.join(p.root, 'dev', 'store3');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  const log = path.join(p.root, 'ddev.log');
  // The registry name is refused; a folder is accepted, when its install.yaml carries no constraint.
  const stubs = `ddev() { echo "ddev $*" >> "$DDEV_LOG" ; if [ "$1 $2" == "add-on get" ] ; then [ -d "$3" ] || return 1 ; grep -q ddev_version_constraint "$3/install.yaml" && return 1 ; printf '%s' '${COMPOSE.replace(/'/g, "'\\''")}' > .ddev/docker-compose.opensearch.yaml ; fi ; return 0 ; }
git() { echo "git $*" >> "$DDEV_LOG" ; mkdir -p "\${@: -1}" ; printf 'name: ddev-opensearch\\nddev_version_constraint: ">= v1.24.10"\\n' > "\${@: -1}/install.yaml" ; }`;
  const r = bash(`${stubs}\ncd ${dir} && magento_add_search`, { DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /^ddev add-on get ddev\/ddev-opensearch\ngit clone -q --depth 1 https:\/\/github\.com\/ddev\/ddev-opensearch\.git \S+\/ddev-opensearch\nddev add-on get \S+\/ddev-opensearch\n$/);
  assert.doesNotMatch(calls, /self-upgrade|poweroff|ddev-router/, 'the container tool of the machine and the shared router are left as they are');
  assert.match(r.stdout, /newer container tool than this machine has/);
  assert.doesNotMatch(fs.readFileSync(path.join(dir, '.ddev', 'docker-compose.opensearch.yaml'), 'utf8'), /opensearch-dashboards/);
});

test('the first feature names no platform in a step, logs in as each admin user and each customer, and creates no account', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /magento|mage-os|adobe/i, s);
  assert.doesNotMatch(feature, /magento/i, 'nor anywhere else in the feature');
  assert.match(feature, /the admin panel/);
  assert.match(feature, /the store/);
  assert.match(feature, /Given I am on the homepage\n\s+Then the response status code should be 200/, 'the front page of the storefront');
  assert.match(feature, /logged in to the admin panel as "<handle>"[\s\S]*?\| admin  \|\n\s+\| sales  \|/, 'each admin account logs in');
  assert.match(feature, /as "admin"\n[\s\S]*?When I go to the "users" admin page\n\s+Then I should not see the access denied page/, 'what the administrator opens');
  assert.match(feature, /as "sales"\n\s+Then I should see the "Sales > Orders" admin menu\n\s+But I should not see the "Catalog" admin menu/, 'what the sales role has');
  assert.match(feature, /as "sales"\n\s+When I go to the "<page>" admin page\n\s+Then I should see the access denied page/, 'and what it is refused');
  for (const handle of ['customer', 'shopper']) assert.match(feature, new RegExp(`^\\s*\\| ${handle} +\\|`, 'm'), `${handle} logs in to the store`);
  assert.doesNotMatch(feature, /webmaster/, 'the workspace account is never written into a test');
  assert.doesNotMatch(feature, /account\/create|I register|create an account/i, 'a suite never creates an account');
  const passwords = feature.match(/the password "([^"]*)"/g) || [];
  assert.deepStrictEqual(passwords, ['the password "wrong-password"'], 'the only password is a wrong one, the subject of its scenario');
});
