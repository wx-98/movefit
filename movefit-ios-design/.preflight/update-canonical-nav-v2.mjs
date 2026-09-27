import fs from 'fs';

const summaryPath = '/Volumes/E/code/codex/movefit/movefit-ios-design/runtime-orchestration-summary.json';
const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf8'));

const items = summary.project.mobileNavigation.items;
const canonical = {};

for (const item of items) {
  const links = items.map((it) => {
    const isActive = it.key === item.key;
    const colorClass = isActive ? 'text-primary font-semibold' : 'text-muted-foreground';
    return `    <a href="#" data-nav-key="${it.key}" data-dom-id="nav-${it.key}" class="min-w-0 flex flex-col items-center justify-center gap-0.5 px-1 h-full ${colorClass} transition-colors">\n      <i data-lucide="${it.icon}" class="w-5 h-5 shrink-0"></i>\n      <span class="text-[11px] leading-none whitespace-nowrap max-w-full truncate">${it.label}</span>\n    </a>`;
  }).join('\n');

  canonical[item.key] = `<nav class="fixed bottom-0 w-full z-50 bg-card/80 backdrop-blur-xl pb-safe shadow-[0_-1px_8px_rgba(0,0,0,0.04)] h-14" data-mobile-nav="global">\n  <div class="w-full max-w-md mx-auto grid grid-cols-5 h-full">\n${links}\n  </div>\n</nav>`;
}

summary.project.mobileNavigation.structure.canonicalHtmlByKey = canonical;
summary.project.sharedProjectShellContract.mobileNavigation.structure.canonicalHtmlByKey = canonical;

fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
console.log('Updated canonicalHtmlByKey v2 for', Object.keys(canonical).join(', '));
