---
name: magento-scenarios
description: Write and run webship-js scenarios for a Magento Open Source store of the Webship Workspace with the Magento step pack (`@webship-js/magento-steps`) — the phrases of the pack by area (the admin panel session, its menu and pages, the store's catalog, the product page and the cart, the customer account), the handles of the users registry, and the workspace command that runs them in the store's container. Use when asked to "write a scenario for this store", "test the sales role", "which step is there for the cart", "add a feature for the customer account", or when a `.feature` file of a Magento project is being written or fixed.
argument-hint: '<site> [what to cover]'
---

# magento-scenarios

Scenarios for a Magento Open Source store of a Webship Workspace (`~/workspace`, container-based,
DDEV by default), written from the steps of [`@webship-js/magento-steps`](https://github.com/webship/magento-steps)
and of [webship-js](https://github.com/webship/webship-js) itself, and run in the store's
container by the workspace's own command. It comes with the Magento plugin
(`@webship.co/workspace-magento`), like the builder (`cmd-magento-project.sh`), the command-line
tool (`cmd-tools-magento-cli.sh`) and the agents `magento-site-builder` and `magento-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The store | `~/workspace/<folder>/<site>`, at `https://<site>.ddev.site`, the admin panel at `/admin` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| The suite's configuration | `<site>/cucumber.js`: the step definitions it loads and the users registry (`worldParameters.users`) |
| The features | `<site>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The pack's steps | `<site>/node_modules/@webship-js/magento-steps/tests/step-definitions/*.steps.js` |
| The pack's own features | `<site>/node_modules/@webship-js/magento-steps/tests/features/*.feature`: written for the same sample catalog, worth reading before writing one |
| webship-js's steps | `<site>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<site>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site>
   ```
   It adds webship-js, the step pack, the users registry and `tests/features/site.feature`, and
   makes sure the default accounts are in the store. It is safe to run again: it adds what is
   missing and keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack
   moves, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<site>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/magento-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with examples above it; open the file when a phrase is not
   obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen. A scenario written without having seen the page asserts
   what you imagine.
4. **Write the feature** in `<site>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --tags "@critical"
   bash cmd-tools-testing.sh <site> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The admin panel and the store have a
sign-in each, and a step for each. The default accounts are in the store already
(`bash cmd-tools-magento-cli.sh <site> --add-users` adds them again if they were removed):

| Handle | Account | What it is | Logs in to |
| --- | --- | --- | --- |
| `admin` | `administrator` | an admin user with the Administrators role | the admin panel |
| `sales` | `sales` | an admin user with the Sales role, and nothing else | the admin panel |
| `customer` | `customer@example.com` (Casey Customer) | a customer with one address, 100 Main Street | the store |
| `shopper` | `shopper@example.com` (Sam Shopper) | a second customer with one address | the store |

```gherkin
Given I am logged in to the admin panel as "sales"
Then I should be logged in to the admin panel as "sales"
Given I am logged in as the customer "customer"
Then I should be logged in to the store as "Casey Customer"
```

## The phrases, by area

Each line is a phrase the pack defines, and each one passed on a store built with
`bash cmd-magento-project.sh <site> --install --add-users` (release 2.4.9 with the sample
catalog, in production mode; the names and the prices in quotes are that store's). Most `should`
steps also take the negative: `should not see`, `should not be`, `should not contain`.

### The admin panel

```gherkin
Given I am logged in to the admin panel as "admin"
When I log in to the admin panel with the username "nobody" and the password "wrong-password"
When I log out of the admin panel
Then I should be logged in to the admin panel as "admin"
Then I should not be logged in to the admin panel
Then the admin page title should be "Dashboard"
Then I should see the "Sales > Orders" admin menu
Then I should not see the "Catalog" admin menu
When I go to the "orders" admin page
Then I should see the access denied page
Then I should see the success message "You have logged out."
Then I should see the error message "The account sign-in was incorrect or your account is disabled temporarily."
```

### The catalog, the product page and the cart

```gherkin
When I open the "Gear > Bags" store menu item
Then the breadcrumbs should be "Home > Gear > Bags"
Then I should see the product "Joust Duffle Bag" in the product list
When I sort the product list by "Price"
Then the product list should be ordered by price ascending
Then the product price should be "$34.00"
When I add the product to the cart
Then the mini cart should show 1 item
When I go to the cart
Then the cart should contain "Joust Duffle Bag"
Then the cart subtotal should be "$34.00"
When I change the cart quantity of "Joust Duffle Bag" to 3
When I remove "Joust Duffle Bag" from the cart
Then I should see the field error "This is a required field."
When I wait for the page to settle
```

### The customer account

```gherkin
Given I am logged in as the customer "customer"
When I log out of the store
Then I should be logged in to the store as "Casey Customer"
Then I should not be logged in to the store
When I go to my "address book" account page
Then my address book should contain "100 Main Street"
Given my address book has no address "9 Scenario Road"
When I delete the address "9 Scenario Road"
When I add the product to my wish list
Then my wish list should contain "Push It Messenger Bag"
When I remove "Push It Messenger Bag" from my wish list
```

An address is added from a table:

```gherkin
When I add the address:
  | Phone Number    | 5125550199      |
  | Street Address  | 9 Scenario Road |
  | Country         | United States   |
  | State/Province  | Texas           |
  | City            | Dallas          |
  | Zip/Postal Code | 75001           |
```

`I am on the homepage`, `I am on "<path>"`, `I should see "<text>"` and
`the response status code should be 200` are webship-js's own steps; its status codes, classes,
landmarks and accessibility audits are used as they are and never redefined for this platform.

## What the scenarios rely on

Every phrase above passed at its first real run on this store; what follows is what they rely
on, and what was left out on purpose.

- **The sample catalog.** The menu (`Gear > Bags`), the products and the prices are the sample
  catalog's: on a store built with `--sample-data no` every catalog phrase above fails. A price
  is asserted as the page writes it (`"$34.00"`).
- **Two sign-ins, two steps.** `I am logged in to the admin panel as "<handle>"` for `admin` and
  `sales`, `I am logged in as the customer "<handle>"` for `customer` and `shopper`. The store
  shows a customer by name (`Casey Customer`), not by handle.
- **A page is loaded before it works.** The pack's steps wait for the page to settle by
  themselves; after a webship-js step that opens a page, add `When I wait for the page to settle`
  before asserting what the page's scripts draw (the first feature does, before `Sign In`).
- **No order in an example.** The pack has the whole checkout (`I place the order`,
  `I should see the order confirmation`), and they are not listed here because an order cannot be
  taken out of a store again: a suite that places one says so, and its store is a throwaway.
- **The cart of a visitor ends with the scenario**; a customer's stays: start a customer's cart
  scenario with `Given my cart is empty`, and take out what the scenario put in.
- **The guards.** `Given my address book has no address "<street>"` clears what a failed run left;
  the pack has the same for a product, a customer, a page and a category in the admin panel
  (`Given there is no product "<sku>"`).

## Rules

- **No account is created in a suite.** No admin user and no customer made in a hook, no
  registration scenario that leaves an account behind. A role the registry does not have is
  asked for, not made.
- **Never the workspace account.** The store's own administrator is not in the registry; `admin`
  is the `administrator` default account.
- **No password in a feature file**, except where a wrong password is the subject.
- **No platform name in a step phrase**: `I am logged in to the admin panel as "admin"`, never a
  phrase that names the platform. The same holds for a custom step.
- **No selector and no address when a step says it**: `the "orders" admin page`, not its path.
- **What a scenario creates, it removes** in the same scenario, under a name nobody else uses.
- **The community edition only**: no access keys, no paid feature, no payment gateway or carrier
  that calls a service outside the store.
- **A custom step is the last resort**: look in the pack and in webship-js first, write it in
  `<site>/tests/step-definitions/` with a comment block and examples, and say it may belong in
  the pack.
- **Everything runs in the container**, through `cmd-tools-testing.sh`. Never `npx cucumber-js`
  or `npx playwright` on the host.
- **A failing scenario is a result.** No `@wip`, no longer timeout, no looser assertion to turn a
  run green: say what the store did.

## Examples that run

`examples/` holds three features that pass on a store built with
`bash cmd-magento-project.sh <site> --install --add-users`. Copy one into the suite and run it:

```bash
cp ~/workspace/ai-skills/magento-scenarios/examples/admin-roles.feature ~/workspace/<folder>/<site>/tests/features/
cd ~/workspace/<folder>
bash cmd-tools-testing.sh <site> --run --path tests/features/admin-roles.feature
```

| Feature | What it shows |
| --- | --- |
| `examples/admin-roles.feature` | The menu of the administrator and of the sales role, a page the sales role is refused, the end of an admin session |
| `examples/catalog-and-cart.feature` | A category from the menu, a sorted list, a product put in the cart, counted and taken out; a product that asks for its options |
| `examples/customer-account.feature` | A customer logging in, an address added and deleted, a wish list filled and emptied, the end of a session |
