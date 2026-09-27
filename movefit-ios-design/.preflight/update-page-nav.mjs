import fs from 'fs';

const summaryPath = '/Volumes/E/code/codex/movefit/movefit-ios-design/runtime-orchestration-summary.json';
const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf8'));

const mobileNavigation = summary.project.mobileNavigation;

for (const page of summary.pages) {
  page.mobileNavigation = mobileNavigation;
}

fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
console.log('Added mobileNavigation to', summary.pages.length, 'pages');
