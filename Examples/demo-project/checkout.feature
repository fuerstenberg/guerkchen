Feature: Checkout
  As a shopper
  I want to pay for the items in my cart
  So that the order is placed

  Scenario: Pay with credit card
    Given a user is logged in
    And the cart is not empty
    When the user chooses credit card
    And the user confirms the order
    Then the order is placed
    And the user receives a confirmation e-mail with the text
      """
      Thank you for your order.
      """
