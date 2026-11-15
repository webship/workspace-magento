Feature: A visitor browses the catalog and fills a cart
  As a visitor
  I want to find a product, put it in my cart and take it out again
  So that the suite proves the catalog and the cart, and places no order

  # For a store built with the sample catalog (the builder's default): the categories, the
  # products and the prices are the sample catalog's. No order is placed: an order cannot be
  # taken out of a store again.

  Scenario: The menu leads to a category
    Given I am on the homepage
    When I open the "Gear > Bags" store menu item
    Then the breadcrumbs should be "Home > Gear > Bags"
    And I should see the product "Joust Duffle Bag" in the product list
    But I should not see the product "Radiant Tee" in the product list

  Scenario: The list is sorted by price
    Given I am on "/gear/bags.html"
    When I sort the product list by "Price"
    Then the product list should be ordered by price ascending

  Scenario: A product goes into the cart, is counted and comes out again
    Given I am on "/joust-duffle-bag.html"
    Then the product price should be "$34.00"
    And the mini cart should show 0 items
    When I add the product to the cart
    Then I should see the success message "You added Joust Duffle Bag to your shopping cart."
    And the mini cart should show 1 item
    When I go to the cart
    Then the cart should contain "Joust Duffle Bag"
    And the cart subtotal should be "$34.00"
    When I change the cart quantity of "Joust Duffle Bag" to 3
    Then the cart subtotal should be "$102.00"
    When I remove "Joust Duffle Bag" from the cart
    Then the cart should not contain "Joust Duffle Bag"

  Scenario: A product with options asks for them
    Given I am on "/radiant-tee.html"
    When I add the product to the cart
    Then I should see the field error "This is a required field."
    And the mini cart should show 0 items
