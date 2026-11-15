/**
 * Magento Open Source for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * command-line tool in the sites folders, their functions and argparse under
 * core/scripts/plugins/magento/, its AI items (ai/ in this package) in the folder of their kind:
 * the agents in AI Agents, the skill in AI Skills, the command in AI Commands, the prompt in AI Prompts.
 * The dashboard needs nothing
 * drawn for it: the builder is in the Build list because it is a cmd-*-project.sh, the row menus
 * are the core's, the AI items are listed like any other. What register() adds is what the assistant
 * is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name, which its functions and its user list are named after. */
export const PLATFORM = 'magento';

/** The DDEV project type of a store: the name the row menus ask for the user list under. */
export const PROJECT_TYPE = 'magento2';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-magento-project.sh', 'cmd-tools-magento-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['magento-site-builder', 'magento-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['magento-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['magento-test'];

/** The prompt the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['magento-build-and-test'];

/** What the assistant is told about Magento Open Source in this workspace. */
export function assistantContext(): string {
  return [
    'Magento Open Source (a plugin, @webship.co/workspace-magento): a store of the community edition, release 2.4.x, is built with',
    '`bash cmd-magento-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos),',
    'in a container like every other project, with its search engine (OpenSearch) in the same project, at https://<name>.ddev.site (the admin panel at /admin),',
    'in production mode, with the sample catalog unless `--sample-data no`. A build takes several minutes and a running store uses about 2 GB of memory: build one at a time and stop a store that is not in use.',
    '`bash cmd-tools-magento-cli.sh <name>` says what the store is; `--run "<command>"` runs the command line of the store (bin/magento) in it,',
    '`--flush-cache` flushes its cache, `--reindex` rebuilds its indexes, `--mode <production|developer>` changes its mode,',
    '`--add-users` adds the default accounts (an administrator, an admin user with a role limited to Sales, and two customers with an address).',
    '`bash cmd-tools-add-users.sh <name> magento` adds the same accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Magento step pack; `--run` runs the suite.',
    `For Magento work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompt ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run php, composer, npm or mysql on the host for a project. Only the community edition is built: never the paid edition, never access keys or a vendor account, never a marketplace extension, never a payment gateway or a carrier that calls a service outside the store.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
