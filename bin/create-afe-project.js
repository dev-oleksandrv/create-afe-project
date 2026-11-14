#!/usr/bin/env node
// Command line of create-afe-project: create a project, or update one to this package's template.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseArgs } from 'node:util';
import * as p from '@clack/prompts';
import { UsageError } from '../src/answers.js';
import { VERSION, create, update } from '../src/project.js';

const HELP = `create-afe-project ${VERSION}

Usage:
  npm create afe-project@latest [directory] [-- options]
  npx create-afe-project@latest [directory] [options]   create a project
  npx create-afe-project@latest update [options]        update the project in the current directory

Options:
  --defaults           do not ask: take --data, then the recorded answers, then the defaults
  --data key=value     answer a question; repeatable
  --data-file <file>   answers from a JSON file; --data wins over it
  --force              create: write into a directory that is not empty
  --no-git             create: do not make the initial Git commit on main
  --allow-dirty        update: run with uncommitted changes
  --quiet              print only errors and the result
  -h, --help           print this help
  -v, --version        print the version
`;

function given(values) {
  const data = values['data-file'] ? JSON.parse(readFileSync(values['data-file'], 'utf8')) : {};
  for (const pair of values.data ?? []) {
    const i = pair.indexOf('=');
    if (i < 1) throw new UsageError(`--data expects key=value, got ${pair}`);
    data[pair.slice(0, i)] = pair.slice(i + 1);
  }
  return Object.fromEntries(Object.entries(data).filter(([k]) => !k.startsWith('_')));
}

async function main() {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      defaults: { type: 'boolean' },
      data: { type: 'string', multiple: true },
      'data-file': { type: 'string' },
      force: { type: 'boolean' },
      'no-git': { type: 'boolean' },
      'allow-dirty': { type: 'boolean' },
      quiet: { type: 'boolean' },
      help: { type: 'boolean', short: 'h' },
      version: { type: 'boolean', short: 'v' },
    },
  });
  if (values.help) return void process.stdout.write(HELP);
  if (values.version) return void process.stdout.write(`${VERSION}\n`);

  const interactive = Boolean(process.stdin.isTTY && process.stdout.isTTY) && !values.defaults;
  const quiet = Boolean(values.quiet);
  const common = { given: given(values), useDefaults: Boolean(values.defaults), interactive, quiet };
  if (interactive) p.intro(`create-afe-project ${VERSION}`);

  if (positionals[0] === 'update') {
    if (positionals.length > 1) throw new UsageError('update takes no directory; run it in the project');
    const r = await update(process.cwd(), { ...common, allowDirty: Boolean(values['allow-dirty']) });
    const lines = [`Updated the template from ${r.from ?? 'an unrecorded version'} to ${r.to}.`];
    if (r.dropped.length) lines.push(`Answers not carried over (no question here): ${r.dropped.join(', ')}.`);
    if (r.migrations.length) lines.push(`Migrations run: ${r.migrations.join(', ')}.`);
    if (r.removed.length) lines.push(`Removed, no longer template-owned: ${r.removed.join(', ')}.`);
    if (r.seeded.length) lines.push(`Created missing seeded files: ${r.seeded.join(', ')}.`);
    if (r.unowned.length) lines.push(`Created files without an owner class (a template defect): ${r.unowned.join(', ')}.`);
    for (const note of r.notes) lines.push(`Warning: ${note}.`);
    lines.push('Next: scripts/check.sh, then a pull request with /create-pr.');
    return void (interactive ? p.outro(lines.join('\n')) : console.log(lines.join('\n')));
  }

  if (positionals.length > 1) throw new UsageError('expected at most one directory');
  let dir = positionals[0];
  if (!dir) {
    if (!interactive) throw new UsageError('name the directory to create the project in');
    dir = await p.text({ message: 'Where should the project go? (a new or empty directory)', placeholder: 'my-project', validate: (v) => (v?.trim() ? undefined : 'Required') });
    if (p.isCancel(dir)) {
      p.cancel('Cancelled; nothing was written.');
      process.exit(130);
    }
  }
  if (interactive) {
    p.note(
      'A few questions about the project, then yes/no questions that turn optional checks on.\n' +
        'Press Enter to keep a default. To change an answer later, run\n' +
        'npx create-afe-project@latest update in the project.',
    );
  }
  const spinner = interactive && !quiet ? p.spinner() : null;
  let spinning = false;
  const { message } = await create(resolve(dir), {
    ...common,
    force: Boolean(values.force),
    git: !values['no-git'],
    quiet: quiet || interactive,
    // Start the spinner once: a second start() leaves its first timer running, and the process
    // never exits.
    log: (msg) => {
      if (!spinner) return;
      if (spinning) spinner.message(msg);
      else spinner.start(msg);
      spinning = true;
    },
  });
  spinner?.stop('Generated files written');
  if (interactive) p.outro(message);
  else console.log(message);
}

main().catch((error) => {
  if (error instanceof UsageError || error?.code?.startsWith?.('ERR_PARSE_ARGS')) {
    console.error(`create-afe-project: ${error.message}\nRun create-afe-project --help for usage.`);
    process.exit(2);
  }
  console.error(`create-afe-project: ${error.message}`);
  process.exit(1);
});
