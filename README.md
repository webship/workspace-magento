# @webship.co/workspace-magento

Magento Open Source for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a
builder that makes a real Magento Open Source store in a container, a command-line tool for the
stores it built, the default accounts, the [Magento step pack](https://github.com/webship/magento-steps)
wired into the workspace's testing setup, and two AI agents that know all of it.

It is a Webship Workspace plugin for one platform. The workspace is container-based (DDEV by default):
a store is a row like any other, so the row menus the core draws (start, stop, launch, backup,
clone, remove, users, tests) work on it unchanged. The core is only the base: the build,
the accounts and the testing hook are all in this package.

It is made from the reference platform plugin,
[`@webship.co/workspace-wordpress`](https://github.com/webship/workspace-wordpress).

Only the community edition is built: Magento Open Source, on the 2.4 line. Never the paid edition
or its features, no B2B, no access keys, no account of a vendor, no marketplace extension, and no
payment gateway or carrier that calls a service outside the store.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require github:webship/workspace-magento   # npm install into the dashboard
bash core/scripts/plugins.sh --activate magento                            # plugins.magento in settings.yml
bash core/scripts/plugins.sh --install magento                             # commands, functions, args, agents
bash core/scripts/plugins.sh --configure magento                           # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an agent you edited stays.

The commands land in the sites folders that are in the workspace (`dev`, `test`, `sandboxes`,
`demos`); the agents land in the AI Agents folder (`ai-agents/`) when the workspace has one, and are
installed into `~/.claude/agents` from there like any other agent.

It needs a Webship Workspace 1.0.7 or later.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, the AI Agents folder its two agents are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate magento --with-needs   # dev and ai-agents are required, activated and installed first
bash core/scripts/plugins.sh --install magento
```

Everything the builder runs for a site runs in the site's own container, through the container tool the workspace already needs; the plugin asks for no command of its own on the machine.

A workspace that knows none of this (Webship Workspace 1.0.8 and older) ignores the keys: add a sites folder and the AI Agents folder yourself, then `--install magento` again.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-magento-project.sh` | The builder, in the Build list as **Magento Open Source (2.4.x)**, installed into every sites folder |
| `commands/cmd-tools-magento-cli.sh` | The command line of the store (`bin/magento`) for one project: what the store is, a command, the cache, the indexes, the mode, the default accounts |
| `scripts/functions/fun-magento.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_magento_users`, `add_magento_users`, `cancel_magento_users`, `testing_configure_magento`), and the three account functions again under the DDEV project type (`set_magento2_users`, …) |
| `scripts/args/arg-magento.sh`, `arg-magento-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `testing/site.feature` | The first feature a store gets when testing is set up |
| `agents/magento-site-builder.md` | The agent that builds and maintains stores with these commands |
| `agents/magento-tester.md` | The agent that writes and runs scenarios with the Magento step pack |
| `src/index.ts` | `register(api)`: what the assistant is told about Magento Open Source here |
| `features/magento.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a store

```bash
cd ~/workspace/dev
bash cmd-magento-project.sh mystore --install --add-users
```

| Flag | What it does |
| --- | --- |
| `--version <x>` | The Magento Open Source 2.4 release to build, by its number: `2.4.9` (the default, the release this plugin was proven on), or another such as `2.4.8-p3` |
| `--install` | Install the store in production mode, with the workspace account as its administrator |
| `--add-users` | With `--install`: add the default accounts, an administrator, an admin user with a role limited to Sales, and two customers with an address |
| `--sample-data <yes\|no>` | With `--install`: the sample catalog of the edition (products, categories, a customer, orders). `yes` by default; `no` gives an empty store and a shorter build |
| `--php-version <x>` | The PHP of the project container (`8.4`; `8.3` is for a 2.4.8 release) |
| `--launch` | Open the store when it is ready |

The store answers at `https://mystore.ddev.site`, the admin panel at `/admin`. A project of the
same name is deleted first. Without `--install` the build stops at the code: the edition has no
installer in the browser.

**The footprint.** A running store uses about 2 GB of memory and several GB of disk, and a build
takes longer than any other platform of the workspace. Build one store at a time and stop one that
is not in use (`ddev stop` in the project). The builder does not start when the machine has less
than 2 GB of memory available. Measured on release 2.4.9 with the sample catalog:

| | |
| --- | --- |
| Memory, running | 2.0 GB: the web container 665 MB, the database 270 MB, the search engine 1.1 GB |
| Disk | 1.4 GB for the project folder, 240 MB for the database volume, 1.7 GB for the image of the search engine |
| Build | 3 minutes 24 seconds with the packages in Composer's cache. The first build downloads the 551 packages of the edition: on a slow connection that took 29 minutes more, with one download tried again |

What the build does, in order:

- **The container.** `ddev config --project-type=magento2` with the docroot `pub`, PHP 8.4,
  MariaDB 11.4 and the Node.js of the workspace (24). The installer of the store writes its own
  settings, so the container tool manages none; it is given the container's database values
  (`db` / `db` / `db`), the same in every project, and nothing personal.
- **The search engine.** The store requires one: OpenSearch 3, from the container tool's own
  add-on (`ddev/ddev-opensearch`), in the same project. The builder keeps the engine only: the
  dashboards service of the add-on is taken out, the engine is not published through the shared
  router (the store reaches it inside the project), and its heap is limited to 512 MB. When the
  container tool of the machine is older than the add-on asks for, the same add-on is installed
  from a clone with its version constraint taken out; the container tool itself is not touched.
- **The packages.** `composer create-project magento/project-community-edition`, then `composer install`, from the public
  Mage-OS mirror of the Magento Open Source packages, `https://mirror.mage-os.org/`. The mirror
  serves the same releases as the vendor's repository without access keys, so a build needs no
  account anywhere and no access keys are asked for or written. Composer runs in the container
  itself, in two steps: the container tool's own `composer create-project` holds the output of a
  dry run until it ends, and with the 551 packages of the edition an older container tool then
  waits on itself forever. A download that is cut short is tried three times and goes on where it
  stopped.
- **The install.** `setup:install`, non-interactive, with the HTTPS address of the project as the
  base URL, the admin path pinned to `admin`, and the workspace account as the administrator.
- **The sample catalog**, unless `--sample-data no`: `sampledata:deploy`, from the same mirror.
- **The settings of a local store**, then **the default accounts** with `--add-users`.
- **Production mode**: the code compiled and the static content deployed, so the pages answer fast
  and the same way every time.
- **The indexes** on "Update on Save" and rebuilt, **cron** run once and not left running, the
  cache flushed, and the first request of the storefront and of the admin panel made.
- **Mail** goes to the container's Mailpit (`ddev mailpit` in the project): nothing leaves the machine.

What the build leaves out or turns off, stated plainly:

- **Two-factor authentication is left out.** The store is installed without the modules
  `Magento_TwoFactorAuth` and `Magento_AdminAdobeImsTwoFactorAuth`: a local test site cannot ask a
  person for a code. Never put a store built here on the internet as it is.
- **The payment gateway and data-export modules bundled with the edition are left out**
  (`PayPal_Braintree*`, `Magento_PaymentServices*`, `Magento_ServiceProxy`, `Magento_Services*`,
  `Magento_SaaSCommon`, `Magento_*DataExporter`). Not configured, a stock install still loads
  scripts from the gateway's servers on every storefront page. They are left out at install
  (`setup:install --disable-modules`), not disabled afterwards: a module disabled later leaves its
  database triggers behind and orders fail. The store has the offline methods of the edition:
  Check / Money order, Flat Rate and Free Shipping.
- **Nothing is fetched or asked at sign-in**: the admin notification feed, the usage-data question
  and the release notification are left out (`Magento_AdminNotification`, `Magento_AdminAnalytics`,
  `Magento_ReleaseNotification`).
- **The sign-in behaves the same way every time**: a long admin session, no secret key in admin
  addresses, one admin account in two browsers, no forced password change, no lock after failed
  sign-ins, no CAPTCHA. These are settings for a store on this machine and for tests.

The store asks an admin user for a password of 7 characters or more with both letters and digits:
`--install` stops before it starts when the workspace account's is not one.

### Work on a store

```bash
bash cmd-tools-magento-cli.sh mystore                                # version, addresses, mode, admin users and customers
bash cmd-tools-magento-cli.sh mystore --run "list"                   # every command of the command line
bash cmd-tools-magento-cli.sh mystore --run "module:status"
bash cmd-tools-magento-cli.sh mystore --flush-cache                  # flush the cache
bash cmd-tools-magento-cli.sh mystore --reindex                      # rebuild every index
bash cmd-tools-magento-cli.sh mystore --mode developer               # or production
bash cmd-tools-magento-cli.sh mystore --add-users                    # the default accounts
bash cmd-tools-magento-cli.sh mystore --cancel-users                 # delete them
```

`--mode production` compiles the code and deploys the static content again; `--mode developer`
serves the files as they are.

The tool has no `--update`, because an update of a store is not one command. It is the platform's
own procedure, by hand, in the project: a Composer change of the release of
`magento/product-community-edition`, then `setup:upgrade` and production mode again, with a backup
first. This plugin does not run it and was not proven on it: for a local store a newer release is
a new build.

### The default accounts

| Account | What it is | Handle in the tests | Logs in to |
| --- | --- | --- | --- |
| the workspace account (Workspace Owner) | the administrator, made by the installer | none: it is never written into a test | the admin panel |
| `administrator` (Store Admin) | an admin user with the Administrators role | `admin` | the admin panel |
| `sales` (Sally Sales) | an admin user with the Sales role: orders, invoices, shipments and credit memos, and nothing else | `sales` | the admin panel |
| `customer@example.com` (Casey Customer) | a customer with one address | `customer` | the store |
| `shopper@example.com` (Sam Shopper) | a second customer with one address | `shopper` | the store |

The four default accounts have the password of the workspace's other default lists. They are for
local stores and for tests. The administrator is a test account of its own, so the features of the
step pack that log in as `admin` run on a built store and the workspace account stays out of every
test. The command line of the store makes an administrator and no other account, so they are made
in the container through the store's own classes, without the browser; the Sales role is made with
them when the store does not have it.

`bash cmd-tools-add-users.sh mystore magento` and `bash cmd-tools-cancel-users.sh mystore magento`
add and remove the same list, and so does the **Users** menu of a project row: the dashboard reads
the DDEV project type of the row (`magento2`), and the list answers to that name too. Removing the
accounts leaves the Sales role in the store: it is a role, not an account.

### Test a store

```bash
bash cmd-tools-testing.sh mystore                 # webship-js, the step pack, the accounts, a first feature
bash cmd-tools-testing.sh mystore --run           # run the suite in the container
bash cmd-tools-testing.sh mystore --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a store it also:

- adds `@webship-js/magento-steps` to `package.json` and lists its step definitions in
  `cucumber.js` after webship-js's own;
- writes into `cucumber.js` what the pack reads: the path of the admin panel (`adminPath`,
  overridable with `ADMIN_PATH`), the command that rebuilds the indexes for the step
  `I rebuild the invalid indexes` (`reindexCommand` and `siteDir`: the suite runs in the container
  of the project, so the command is `php bin/magento indexer:reindex` in the root of the store), and
  the users registry (`users`: the handles above, overridable with `STORE_<HANDLE>_USER` or
  `STORE_<HANDLE>_EMAIL`, and `STORE_<HANDLE>_PASSWORD`);
- tells Firefox in `playwright.config.ts` not to react to a change of network
  (`network.notify.changed`), for the run described below;
- places `tests/features/site.feature` when the project has none, and makes sure the default
  accounts are in the store.

Run it again and it adds what is missing and keeps what you changed.

`site.feature` covers the front page of the storefront, the sign-in of the admin panel for each
admin account, what the administrator opens and what the Sales role is refused, and the sign-in of
each customer, with the phrases of the pack. The steps of the pack wait for a page to settle by
themselves; after a step of webship-js that opens a page, `I wait for the page to settle` does the
same.

**On a machine where other projects start and stop** while a suite runs, Chromium aborts every
request in flight (`net::ERR_NETWORK_CHANGED`). Run in Firefox then:
`bash cmd-tools-testing.sh mystore --run --browser firefox`. The workspace's testing setup installs
Chromium only, so Firefox is installed in the container by hand, once, and again after the
container is rebuilt:

```bash
ddev exec "PLAYWRIGHT_BROWSERS_PATH=/mnt/ddev-global-cache/ms-playwright PLAYWRIGHT_SKIP_BROWSER_GC=1 npx playwright install --with-deps firefox"
```

## The agents

| Agent | Use it to |
| --- | --- |
| `magento-site-builder` | Build, maintain or remove a store with the commands above, in containers only, one at a time, with the community edition and nothing connected outside the store |
| `magento-tester` | Set the testing stack up, look at the store in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |

After `--install` they are in the AI Agents folder of the dashboard; **Install** there puts one into
`~/.claude/agents`, or from the command line:

```bash
cd ~/workspace/ai-agents
bash cmd-tools-ai-items.sh magento-tester --install
```

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the agents, the functions against a scaffolded project
```
