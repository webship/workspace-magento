Feature: The store answers and its accounts work
  As the owner of the store
  I want the front page, the admin panel and each default account to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-add-users.sh); a scenario logs in by a handle of
  # the users registry in cucumber.js, so no password of an account is written here.

  @critical
  Scenario: The front page of the store is served
    Given I am on the homepage
    Then the response status code should be 200
    When I wait for the page to settle
    Then I should see "Sign In"
    And I should not be logged in to the store

  @critical
  Scenario: The admin panel asks for an account
    When I log in to the admin panel with the username "nobody" and the password "wrong-password"
    Then I should see the error message "The account sign-in was incorrect or your account is disabled temporarily."
    And I should not be logged in to the admin panel

  Scenario Outline: Each admin user logs in to the admin panel
    Given I am logged in to the admin panel as "<handle>"
    Then I should be logged in to the admin panel as "<handle>"

    Examples:
      | handle |
      | admin  |
      | sales  |

  Scenario: The administrator has the whole menu and is refused nothing
    Given I am logged in to the admin panel as "admin"
    Then the admin page title should be "Dashboard"
    And I should see the "Sales > Orders" admin menu
    And I should see the "Catalog" admin menu
    And I should see the "Stores" admin menu
    And I should see the "System" admin menu
    When I go to the "users" admin page
    Then I should not see the access denied page
    And the admin page title should be "Users"

  Scenario: The sales role has the Sales menu only
    Given I am logged in to the admin panel as "sales"
    Then I should see the "Sales > Orders" admin menu
    But I should not see the "Catalog" admin menu
    And I should not see the "Customers" admin menu
    And I should not see the "Stores" admin menu
    And I should not see the "System" admin menu

  Scenario: The sales role opens the orders
    Given I am logged in to the admin panel as "sales"
    When I go to the "orders" admin page
    Then the admin page title should be "Orders"
    And I should not see the access denied page

  Scenario Outline: The sales role is refused outside sales
    Given I am logged in to the admin panel as "sales"
    When I go to the "<page>" admin page
    Then I should see the access denied page

    Examples:
      | page             |
      | products         |
      | customers        |
      | cache management |
      | users            |

  Scenario: An admin user logs out of the admin panel
    Given I am logged in to the admin panel as "sales"
    When I log out of the admin panel
    Then I should see the success message "You have logged out."
    And I should not be logged in to the admin panel

  Scenario Outline: A customer logs in to the store
    Given I am logged in as the customer "<handle>"
    Then I should be logged in to the store as "<name>"

    Examples:
      | handle   | name           |
      | customer | Casey Customer |
      | shopper  | Sam Shopper    |

  Scenario: A customer has an address to deliver to
    Given I am logged in as the customer "customer"
    When I go to my "address book" account page
    Then my address book should contain "100 Main Street"

  Scenario: A customer logs out of the store
    Given I am logged in as the customer "shopper"
    When I log out of the store
    Then I should not be logged in to the store

  Scenario: The account pages need a customer
    When I go to my "orders" account page
    Then I should see "Customer Login"
    And I should not be logged in to the store
