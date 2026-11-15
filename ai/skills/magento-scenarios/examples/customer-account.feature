Feature: A customer uses the account
  As a customer
  I want to log in, keep my addresses and a wish list, and log out
  So that the suite proves the account pages and leaves the account as it found it

  # The customers are the default ones; a scenario logs in by a handle of the users registry.

  Scenario: A customer logs in and has an address to deliver to
    Given I am logged in as the customer "customer"
    Then I should be logged in to the store as "Casey Customer"
    When I go to my "address book" account page
    Then my address book should contain "100 Main Street"

  Scenario: An address is added to the address book and deleted
    Given I am logged in as the customer "customer"
    And my address book has no address "9 Scenario Road"
    When I add the address:
      | Phone Number    | 5125550199      |
      | Street Address  | 9 Scenario Road |
      | Country         | United States   |
      | State/Province  | Texas           |
      | City            | Dallas          |
      | Zip/Postal Code | 75001           |
    Then I should see the success message "You saved the address."
    And my address book should contain "9 Scenario Road"
    When I delete the address "9 Scenario Road"
    Then I should see the success message "You deleted the address."
    And my address book should not contain "9 Scenario Road"
    But my address book should contain "100 Main Street"

  Scenario: A product is added to the wish list and removed
    Given I am logged in as the customer "shopper"
    And I am on "/push-it-messenger-bag.html"
    When I add the product to my wish list
    Then my wish list should contain "Push It Messenger Bag"
    When I remove "Push It Messenger Bag" from my wish list
    Then my wish list should not contain "Push It Messenger Bag"

  Scenario: Logging out ends the session, and the account pages need a customer
    Given I am logged in as the customer "shopper"
    When I log out of the store
    Then I should not be logged in to the store
    When I go to my "orders" account page
    Then I should see "Customer Login"
