@auth
Feature: Login
  As a registered user
  I want to log in with my e-mail address
  So that I can see my personal dashboard

  Background:
    Given a user exists
    And a user is logged out

  Scenario: Successful login
    Given a user is on the login page
    When the user enters valid credentials
    And the user clicks login
    Then the user sees the dashboard

  Scenario Outline: Failed login
    Given a user is on the login page
    When the user enters "<email>" and "<password>"
    Then the user sees the error "<message>"

    Examples:
      | email          | password | message              |
      | wrong@test.de  | secret   | Unknown user         |
      | user@test.de   | wrong    | Wrong password       |
