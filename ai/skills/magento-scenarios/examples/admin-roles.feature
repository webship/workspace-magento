Feature: Each admin user gets the admin panel of its role
  As the owner of the store
  I want the administrator to reach everything and the sales role only the sales
  So that a change of role resources is caught by the suite

  # The accounts are the default ones; a scenario logs in by a handle of the users registry.

  Scenario: The administrator has the whole menu
    Given I am logged in to the admin panel as "admin"
    Then I should be logged in to the admin panel as "admin"
    And the admin page title should be "Dashboard"
    And I should see the "Sales > Orders" admin menu
    And I should see the "Catalog" admin menu
    And I should see the "System" admin menu

  Scenario: The sales role has the Sales menu only
    Given I am logged in to the admin panel as "sales"
    Then I should see the "Sales > Orders" admin menu
    But I should not see the "Catalog" admin menu
    And I should not see the "System" admin menu

  Scenario: The sales role opens the orders and is refused the products
    Given I am logged in to the admin panel as "sales"
    When I go to the "orders" admin page
    Then the admin page title should be "Orders"
    And I should not see the access denied page
    When I go to the "products" admin page
    Then I should see the access denied page

  Scenario: An admin user logs out of the admin panel
    Given I am logged in to the admin panel as "sales"
    When I log out of the admin panel
    Then I should see the success message "You have logged out."
    And I should not be logged in to the admin panel
