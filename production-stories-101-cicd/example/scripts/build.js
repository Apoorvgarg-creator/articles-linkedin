// Stand-in build step: copy src to dist and stamp the commit SHA.
import { cpSync, mkdirSync, writeFileSync } from 'node:fs';

mkdirSync('dist', { recursive: true });
cpSync('src', 'dist/src', { recursive: true });
writeFileSync(
  'dist/VERSION',
  `${process.env.GITHUB_SHA || 'local'}\n`
);
console.log('built dist/ for', process.env.GITHUB_SHA || 'local');
