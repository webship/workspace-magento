Build a Magento Open Source store in a sites folder and prove it with its first webship-js feature.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Build a Magento Open Source store named <name> in this sites folder and test it with webship-js
# ~/workspace/<dev|test|sandboxes|demos> · https://<name>.ddev.site · container-based (DDEV by default)
# the builder deletes a project of the same name first: stop if <name> is a store somebody still needs
# nothing on the host: no bin/magento, composer, npm or mysql outside the store's container
# the community edition only: no access keys, no account of a vendor, no marketplace extension
# a running store takes about 2 GB of memory: look at free -g first, and stop if less is available
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-magento-project.sh <name> --install --add-users
   (the sample catalog comes with it; --sample-data no leaves it out; --version <x> for another 2.4 release)
2. bash cmd-tools-magento-cli.sh <name>
   tell me the version, the address, the mode, the admin users and the customers it lists
3. bash cmd-tools-testing.sh <name>
   webship-js, the step pack, the users registry and tests/features/site.feature
4. bash cmd-tools-testing.sh <name> --dry-run --path tests/features/site.feature
5. bash cmd-tools-testing.sh <name> --run --path tests/features/site.feature

If a command fails, show the line that failed and stop. Do not retry with other flags.
When the feature is green: the address, the version, how many scenarios and steps passed.
Then ask me whether to keep the store or remove it with: bash cmd-tools-remove.sh <name>
"""
```
