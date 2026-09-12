#!/usr/bin/env node
// Administrative CLI: requires an explicit project. Never embeds credentials.
const path = require('node:path');
const {createRequire} = require('node:module');
const backend = createRequire(path.join(__dirname, '../../functions/package.json'));
const {initializeApp, applicationDefault} = backend('firebase-admin/app');
const {getFirestore, Timestamp} = backend('firebase-admin/firestore');
const {getAuth} = backend('firebase-admin/auth');
const {randomUUID} = require('node:crypto');
const args = process.argv.slice(2);
const command = args.shift();
const option = name => { const at = args.indexOf(`--${name}`); return at < 0 ? null : args[at + 1]; };
async function main() {
  const projectId = option('project');
  if (!projectId || !['flags', 'invite', 'disable', 'admin', 'inspect'].includes(command)) {
    throw Error('Usage: node tools/maintenance/journal-pilot.cjs flags|invite|disable|admin|inspect --project PROJECT [--uid UID] [--expires ISO_DATE] [--enabled true|false] [--test true|false]');
  }
  const emulated = !!process.env.FIRESTORE_EMULATOR_HOST;
  if (emulated && !projectId.startsWith('demo-')) throw Error('Emulators require a demo- project');
  if (!emulated && projectId.startsWith('demo-')) throw Error('Demo projects require running emulators');
  initializeApp({projectId, ...(emulated ? {} : {credential: applicationDefault()})});
  const db = getFirestore();
  if (command === 'flags') {
    const flags = {};
    for (const [optionName, field] of [['enabled', 'journalEnabled'], ['review', 'reviewEnabled'], ['community', 'communityEnabled'], ['community-write', 'communityWriteEnabled']]) {
      const value = option(optionName);
      if (value == null) continue;
      if (!['true', 'false'].includes(value)) throw Error(`--${optionName} must be true|false`);
      flags[field] = value === 'true';
    }
    if (!Object.keys(flags).length) throw Error('Specify at least one feature flag');
    await db.doc('pilotConfig/features').set({...flags, schemaVersion: 1}, {merge: true});
  } else {
    const uid = option('uid');
    if (!uid || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) throw Error('Valid --uid required');
    const user = await db.doc(`users/${uid}`).get();
    if (!user.exists || (await db.doc(`_deletedUsers/${uid}`).get()).exists) throw Error('Active PAWLINK account required');
    if (command === 'inspect') {
      const participant = (await db.doc(`pilotParticipants/${uid}`).get()).data();
      const pets = await db.collection(`users/${uid}/journalPets`).get();
      console.log(JSON.stringify({status: participant?.status || 'not invited', activated: !!participant?.activatedAt,
        pets: pets.docs.map(p => ({id: p.id, entryCount: p.get('entryCount'), usedBytes: p.get('usedBytes'), reservedBytes: p.get('reservedBytes'), deleting: !!p.get('deletedAt')}))}, null, 2));
      return;
    }
    if (command === 'admin') {
      const account = await getAuth().getUser(uid);
      await getAuth().setCustomUserClaims(uid, {...account.customClaims, pilotAdmin: true});
      await db.doc(`pilotParticipants/${uid}`).set({isAdmin: true}, {merge: true});
    } else {
      const fields = {status: command === 'invite' ? 'invited' : 'disabled', schemaVersion: 1};
      if (command === 'invite') {
        const expires = Date.parse(option('expires'));
        if (!Number.isFinite(expires) || expires <= Date.now()) throw Error('Future --expires ISO_DATE required');
        fields.expiresAt = Timestamp.fromMillis(expires);
        fields.isTest = option('test') === 'true';
      }
      await db.doc(`pilotParticipants/${uid}`).set(fields, {merge: true});
    }
  }
  await db.collection('_pilotAdminAudit').doc(randomUUID()).set({source: 'credentialed-cli', action: command,
    target: option('uid'), createdAt: Timestamp.now(), schemaVersion: 1});
  console.log(`Pilot ${command} completed for explicit project ${projectId}.`);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
