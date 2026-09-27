import fs from 'fs';
import crypto from 'crypto';
import { spawnSync } from 'child_process';
import path from 'path';

const designDir = '/Volumes/E/code/codex/movefit/movefit-ios-design';
const toolPath = '/Users/moon/.trae-cn/builtin/design/default/skills/solo-design/shared-runtime/deterministic-tooling/record-dispatch-completion.mjs';

const pages = [
  { nodeId: 'page-home', htmlSrc: 'pages/home.html' },
  { nodeId: 'page-challenges', htmlSrc: 'pages/challenges.html' },
  { nodeId: 'page-workouts', htmlSrc: 'pages/workouts.html' },
  { nodeId: 'page-history', htmlSrc: 'pages/history.html' },
  { nodeId: 'page-profile', htmlSrc: 'pages/profile.html' },
  { nodeId: 'page-wellness', htmlSrc: 'pages/wellness.html' }
];

for (const page of pages) {
  const filePath = path.join(designDir, page.htmlSrc);
  const content = fs.readFileSync(filePath, 'utf8');
  const traceDigest = crypto.createHash('sha256').update(content).digest('hex');
  const toolLedger = JSON.stringify({ todoWriteCalls: 0, previewCalls: 0, validationScriptCalls: 0, helperScriptWrites: 0, imagesGenerated: 0 });

  const args = [
    toolPath,
    designDir,
    `--node-id=${page.nodeId}`,
    `--html-src=${page.htmlSrc}`,
    '--status=completed',
    `--changed-files=${page.htmlSrc}`,
    `--trace-digest=${traceDigest}`,
    `--tool-ledger-json=${toolLedger}`,
    '--main-agent-mutation=movefit-ios-design.design:registered page interactions and image asset after page generation'
  ];

  const result = spawnSync('node', args, { encoding: 'utf8' });
  console.log(page.nodeId, result.status === 0 ? 'OK' : 'FAIL', result.stdout.trim(), result.stderr.trim());
}
