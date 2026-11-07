// Use Cloudflare's pinned build-output helpers, never upload the project directory.
import { readFile, mkdir, copyFile, readdir, rm } from 'node:fs/promises';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
// A temporary install may be used without adding node_modules to the Godot project.
const dependencies = process.env.WEAPON_LAB_CF_DEPENDENCIES || join(root, 'node_modules');
const { cleanBuildOutputDir, writeRootConfig, writeWorkerConfig, writeAssets, readBuildOutput } = await import(
  pathToFileURL(join(dependencies, '@cloudflare/build-output-utils/dist/index.mjs'))
);
const { InputWorkerSchema } = await import(
  pathToFileURL(join(dependencies, '@cloudflare/config/dist/index.mjs'))
);
const manifest = JSON.parse(await readFile(join(root, 'publish/data-version.json'), 'utf8'));
if (!/^data-\d+\.json$/.test(manifest.package_url)) throw new Error('Expected local versioned data snapshot');
const bytes = await readFile(join(root, 'publish', manifest.package_url));
if (bytes.length !== manifest.size || createHash('sha256').update(bytes).digest('hex') !== manifest.sha256) {
  throw new Error('Data snapshot checksum mismatch');
}
const outputRoot = join(root, '.build/cloudflare');
const publicRoot = join(outputRoot, 'public');
await mkdir(publicRoot, { recursive: true });
const files = ['data-version.json', manifest.package_url, '_headers', 'index.html'];
// Old clients may still be downloading the previous snapshot during rollout.
if ((await readdir(join(root, 'publish'))).includes('data-2.json')) files.push('data-2.json');
for (const name of await readdir(publicRoot)) if (!files.includes(name)) await rm(join(publicRoot, name));
for (const name of files) await copyFile(join(root, 'publish', name), join(publicRoot, name));
await cleanBuildOutputDir(outputRoot);
await writeRootConfig(outputRoot, undefined, { isPreview: false });
await writeWorkerConfig({ root: outputRoot, config: InputWorkerSchema.parse({
  name: 'dfbtk', compatibilityDate: '2026-11-07', workersDev: true,
  assets: { htmlHandling: 'auto-trailing-slash', notFoundHandling: 'none' }
}) });
await writeAssets({ root: outputRoot, sourceDirectory: publicRoot });
await readBuildOutput(outputRoot);
console.log(`CLOUDFLARE_BUILD: PASS; ${files.length} public files; data ${manifest.version_name} (${manifest.data_version})`);
console.log('Deploy from .build/cloudflare with: cf deploy --prebuilt');
