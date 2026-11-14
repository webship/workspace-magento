import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, PROJECT_TYPE, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;
const FUNCTIONS = 'scripts/functions/fun-magento.sh';
/** The functions file without its comment lines: what runs. */
const code = () => read(FUNCTIONS).split('\n').filter((l) => !/^\s*#/.test(l)).join('\n');

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const pkg = JSON.parse(read('package.json'));
  for (const f of named) assert.ok(pkg.files.includes(f.split('/')[0]), `${f} is published with the package`);
  assert.strictEqual(pkg.version, '1.0.7');
  assert.strictEqual(pkg.devDependencies['@webship.co/workspace-plugin-api'], '^1.0.7');
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/magento\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read(FUNCTIONS), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-magento-project.sh'), /^# workspace-name: Magento Open Source/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-magento-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the functions carry the names the core\'s tools look for, under the plugin\'s name and under the project type', () => {
  const src = read(FUNCTIONS);
  for (const fn of ['set_magento_users', 'add_magento_users', 'cancel_magento_users', 'testing_configure_magento', 'magento_build', 'magento_cli_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  // The Users menu of a project row asks for the list under the DDEV project type.
  assert.strictEqual(PROJECT_TYPE, 'magento2');
  for (const verb of ['set', 'add', 'cancel']) {
    assert.match(src, new RegExp(`^function ${verb}_${PROJECT_TYPE}_users\\(\\) \\{ ${verb}_magento_users ; \\}$`, 'm'), `${verb}_${PROJECT_TYPE}_users is the same list`);
  }
  assert.doesNotMatch(src, /^function testing_configure_magento2/m, 'one testing hook: the core calls every testing_configure_* it finds');
});

test('the plugin is the whole of the platform: it calls none of the platform functions the workspace base carries', () => {
  const src = code();
  for (const fn of ['build_distribution', 'composer_create_project', 'composer_install_retry', 'install_drupal_with_drush', 'enable_drupal_extra_components',
    'add_drush', 'drush_cr', 'drush_set_debug_on', 'set_default_settings', 'load_distribution_users', 'add_users', 'cancel_users',
    'wordpress_build', 'odoo_build']) {
    assert.doesNotMatch(src, new RegExp(`(^|[^a-z0-9_])${fn}([^a-z0-9_]|$)`, 'm'), `${fn} is the base's: the plugin has its own`);
  }
  assert.doesNotMatch(src, /functions\/fun-|ddev drush|ddev wp /, 'no file of the base is sourced, and no other platform\'s tool is run');
  // What it does ask of the workspace: the general helpers, each of them used.
  for (const helper of ['trim_project_name', 'drop_database', 'ddev_up', 'ddev_nodejs_version']) {
    assert.match(src, new RegExp(`(^|[^a-z_])${helper}([^a-z_]|$)`, 'm'), `${helper} is a general helper of the workspace`);
  }
  for (const f of manifest.commands.files) {
    assert.doesNotMatch(read(f), /WORKSPACE_SCRIPTS\}\/args\/|build_distribution/, `${f} uses the plugin's own args and build`);
  }
});

test('the container of a store: the project type, the docroot, the database, the Node.js of the workspace, and settings the installer writes', () => {
  const src = code();
  assert.match(src, /readonly MAGENTO_PROJECT_TYPE='magento2';/);
  assert.match(src, /readonly MAGENTO_DATABASE='mariadb:11\.4';/);
  assert.match(src, /ddev config --project-type=\$\{MAGENTO_PROJECT_TYPE\} --docroot="\$\{docroot\}" --project-name=\$\{PROJECT_NAME\} \\\n\s+--upload-dirs=media --disable-settings-management \\\n\s+--php-version=\$\{php_version\} --database=\$\{MAGENTO_DATABASE\} \\\n\s+--nodejs-version=\$\(ddev_nodejs_version\)/);
  assert.match(read('commands/cmd-magento-project.sh'), /^distribution_webroot="pub";$/m, 'the docroot is pub');
  assert.match(read('scripts/args/arg-magento.sh'), /--php-version',\n\s+default="8\.4"/, 'PHP 8.4 by default');
  assert.match(src, /--db-host=db --db-name=db --db-user=db --db-password=db \\/, 'the installer gets the container\'s own database values');
  assert.doesNotMatch(src, /--db-(host|name|user|password)=(?!db )/, 'and no other');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('the community edition only: the public mirror, no keys, no account', () => {
  const src = code();
  assert.match(src, /readonly MAGENTO_MIRROR='https:\/\/mirror\.mage-os\.org\/';/);
  assert.match(src, /readonly MAGENTO_PROJECT='magento\/project-community-edition';/);
  assert.match(src, /composer create-project --repository-url='\$\{MAGENTO_MIRROR\}' '\$\{MAGENTO_PROJECT\}:\$\{version\}' \$\{tmp\} --no-interaction --prefer-dist --no-install/);
  assert.match(src, /&& ddev composer install --no-interaction --prefer-dist ;/, 'then the packages');
  assert.doesNotMatch(src, /ddev composer create-project|ddev composer create /, 'never the container tool\'s own create-project: an older one waits on itself with a project of this size');
  for (const f of ['README.md', FUNCTIONS, ...manifest.commands.files, ...manifest.scripts.args, 'src/index.ts', 'testing/site.feature']) {
    const text = read(f);
    assert.doesNotMatch(text, /repo\.magento\.com|auth\.json"|COMPOSER_AUTH|enterprise-edition|project-enterprise|magento\/product-enterprise/i, `${f}: nothing of the vendor's repository or the paid edition`);
    assert.doesNotMatch(text, /Adobe Commerce|marketplace\.magento/i, `${f} names the community edition only`);
  }
  assert.match(read('README.md'), /https:\/\/mirror\.mage-os\.org\//, 'the README says where the packages come from');
  assert.match(read('README.md'), /without access keys/, 'and why');
});

test('the install keeps the store to itself: gateway, data-export and two-factor modules left out, HTTPS, a pinned admin path', () => {
  const src = code();
  const modules = (src.match(/^readonly MAGENTO_DISABLED_MODULES='([^']+)';$/m) || [])[1].split(',');
  assert.deepStrictEqual(modules, [...new Set(modules)], 'no module twice');
  for (const m of ['Magento_TwoFactorAuth', 'Magento_AdminAdobeImsTwoFactorAuth', 'PayPal_Braintree', 'PayPal_BraintreeGraphQl', 'Magento_PaymentServicesBase',
    'Magento_PaymentServicesPaypal', 'Magento_ServiceProxy', 'Magento_ServicesConnector', 'Magento_SaaSCommon', 'Magento_DataExporter', 'Magento_SalesDataExporter',
    'Magento_AdminNotification', 'Magento_AdminAnalytics', 'Magento_ReleaseNotification']) {
    assert.ok(modules.includes(m), `${m} is left out`);
  }
  for (const m of ['Magento_OfflinePayments', 'Magento_OfflineShipping', 'Magento_Sales', 'Magento_Checkout', 'Magento_Customer']) assert.ok(!modules.includes(m), `${m} is installed`);
  assert.match(src, /setup:install \\\n\s+--disable-modules='\$\{MAGENTO_DISABLED_MODULES\}' \\/, 'left out at install, not disabled afterwards');
  assert.doesNotMatch(src, /module:disable/, 'a module is never disabled after the install');
  assert.match(src, /--base-url='\$\{base_url\}\/' --base-url-secure='\$\{base_url\}\/' --use-secure=1 --use-secure-admin=1 --use-rewrites=1 \\/, 'the HTTPS address of the project');
  assert.match(src, /local base_url="https:\/\/\$\{PROJECT_NAME\}\.ddev\.site" ;/);
  assert.match(src, /--backend-frontname='\$\{MAGENTO_ADMIN_PATH\}' \\/, 'the admin path is pinned');
  assert.match(src, /readonly MAGENTO_ADMIN_PATH='admin';/);
  assert.match(src, /--admin-user=\$\(printf '%q' "\$\{account_name\}"\) --admin-password=\$\(printf '%q' "\$\{account_pass\}"\)/, 'the administrator is the workspace account');
  assert.match(src, /--search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 \\/);
  assert.match(src, /--no-interaction"/);
  // The offline methods of the edition, and nothing that calls out.
  for (const setting of ['payment/checkmo/active 1', 'carriers/flatrate/active 1', 'carriers/freeshipping/active 1', 'analytics/subscription/enabled 0', 'admin/security/use_form_key 0']) {
    assert.ok(src.includes(setting), `${setting} is a setting of a local store`);
  }
});

test('the build ends in production mode with the static content, indexes on save, cron once and a flushed cache', () => {
  const src = code();
  const build = src.slice(src.indexOf('function magento_build()'), src.indexOf('function magento_accounts()'));
  const order = ['setup:install', 'sampledata:deploy', 'setup:upgrade', 'magento_local_settings ||', 'add_magento_users ;', 'magento_set_mode production', 'indexer:set-mode realtime', 'indexer:reindex', 'cron:run', 'cache:flush'];
  let at = -1;
  for (const part of order) {
    const next = build.indexOf(part, at + 1);
    assert.ok(next > at, `${part} comes in its turn`);
    at = next;
  }
  assert.match(src, /deploy:mode:set production --skip-compilation \\\n\s+&& \$\{MAGENTO_CONSOLE_HEAVY\} setup:di:compile \\\n\s+&& \$\{MAGENTO_CONSOLE_HEAVY\} setup:static-content:deploy -f --jobs=2 en_US/);
  assert.match(build, /if \[ ! "\$\{SAMPLE_DATA\}" == 'no' \] ; then/, 'the sample catalog is an option that defaults on');
  assert.match(read('scripts/args/arg-magento.sh'), /'--sample-data',\n\s+default="yes",\n\s+choices=\['yes', 'no'\]/);
  assert.match(build, /magento_retry magento_download "\$\{version\}"/, 'the download of the packages is tried again');
  assert.match(build, /magento_retry ddev exec "\$\{MAGENTO_CONSOLE\} sampledata:deploy/, 'and the download of the sample catalog');
  assert.doesNotMatch(src, /cron:install/, 'cron is run once and not left running');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-magento-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('agents/magento-tester.md');
  assert.match(tester, /Never create an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
  assert.match(tester, /Never the workspace account/);
  assert.match(tester, /`admin` \| `administrator` \(Store Admin\)/, 'the tester knows the administrator test account by its handle');
  assert.match(tester, /--browser firefox/, 'and the lane for a busy machine');
  const builder = read('agents/magento-site-builder.md');
  assert.match(builder, /Containers only/);
  assert.match(builder, /Community edition only/);
  assert.match(builder, /One store at a time/);
  assert.match(builder, /has no `--update`/, 'the builder says what an update is instead of inventing one');
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'magento', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only Webship, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, FUNCTIONS, 'src/index.ts', ...manifest.commands.files, ...manifest.scripts.args];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /CMS plugin/i, `${f}: a Webship Workspace plugin, a platform plugin`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  const readme = read('README.md');
  for (const c of COMMANDS) assert.ok(readme.includes(c), `the README lists ${c}`);
  assert.match(readme, /container-based \(DDEV by default\)/);
  assert.match(readme, /Webship Workspace plugin/);
  assert.match(readme, /`administrator` \(Store Admin\) \| an admin user with the Administrators role \| `admin`/, 'the README lists the administrator test account');
  assert.match(readme, /Two-factor authentication is left out/, 'the README says plainly that the two-factor modules are not installed');
  assert.match(readme, /has no `--update`/, 'the README says what an update is');
  assert.match(readme, /cmd-tools-add-users\.sh mystore magento/, 'the README names the core tool for the accounts');
});
