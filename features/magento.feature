Feature: The Magento plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Magento Open Source
  builder, the AI Agents folder lists the Magento agents, and the Plugins page lists the plugin
  with its steps.

  Scenario: The plugin is listed on the Plugins page
    Given I am on "/settings/plugins"
     Then I should see "Magento Open Source"
      And I should see "@webship.co/workspace-magento"

  Scenario: A sites folder offers the Magento Open Source builder
    Given I am on "/dev"
     Then "option[value='cmd-magento-project.sh']" should be attached

  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents"
     Then I should see "magento-site-builder"
      And I should see "magento-tester"
