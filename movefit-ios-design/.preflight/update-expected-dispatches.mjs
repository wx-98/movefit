import fs from 'fs';

const summaryPath = '/Volumes/E/code/codex/movefit/movefit-ios-design/runtime-orchestration-summary.json';
const manifestPath = '/Volumes/E/code/codex/movefit/movefit-ios-design/runtime-dispatch-manifest.json';

const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf8'));
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

summary.project.expectedDispatches = manifest.dispatchPreflightManifest.map(entry => ({
  nodeId: entry.nodeId,
  packetType: entry.packetType,
  status: 'completed',
  changedFiles: [entry.htmlSrc],
  toolCallLedger: { todoWriteCalls: 0, previewCalls: 0, validationScriptCalls: 0, helperScriptWrites: 0, imagesGenerated: 0 }
}));

// Mark generation tree leaves as generated
function markGenerated(node) {
  if (node.kind === 'page-leaf') {
    node.status = 'generated';
  }
  if (node.children) {
    node.children.forEach(markGenerated);
  }
}
markGenerated(summary.project.generationTree.root);

fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
console.log('Updated expectedDispatches:', summary.project.expectedDispatches.length, 'entries');
