import fs from 'fs';

const summaryPath = '/Volumes/E/code/codex/movefit/movefit-ios-design/runtime-orchestration-summary.json';
const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf8'));

// Ensure sharedProjectShellContract.mobileNavigation has the canonical HTML
const canonical = summary.project.mobileNavigation.structure.canonicalHtmlByKey;
summary.project.sharedProjectShellContract = summary.project.sharedProjectShellContract || {};
summary.project.sharedProjectShellContract.mobileNavigation = summary.project.mobileNavigation;

// Remove per-page mobileNavigation as the manifest reads from sharedProjectShellContract
for (const page of summary.pages) {
  delete page.mobileNavigation;
}

fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
console.log('Fixed mobileNavigation structure in sharedProjectShellContract');
