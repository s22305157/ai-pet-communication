// Package only ciphertext. Never decrypt knowledge or read credentials here.
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const root = path.resolve(__dirname, '..');
const bytes = fs.readFileSync(path.join(root, 'assets/ai_logic/knowledge/rag_index.json'));
if (!/^[A-Za-z0-9+/=\s]+$/.test(bytes.toString('utf8')) || bytes.length < 40) {
  throw new Error('Refusing to package a non-encrypted knowledge index');
}
const destination = path.join(root, 'functions/knowledge');
fs.mkdirSync(destination, {recursive: true});
fs.writeFileSync(path.join(destination, 'rag_index.enc'), bytes);
fs.writeFileSync(path.join(destination, 'manifest.json'), JSON.stringify({
  schemaVersion: 1,
  sha256: createHash('sha256').update(bytes).digest('hex'),
}, null, 2) + '\n');
