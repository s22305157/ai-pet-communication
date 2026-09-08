const {test, before, after, beforeEach} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, getDocs, collection, query, where, updateDoc, deleteDoc, serverTimestamp, Timestamp} = require('firebase/firestore');
const {ref, uploadBytes, getBytes} = require('firebase/storage');
let env;
const user = uid => ({uid, email: `${uid}@example.test`, displayName: uid, photoUrl: null,
  points: 1, membershipTier: 'free', hasCompletedOnboarding: false,
  createdAt: Timestamp.now(), lastLoginAt: Timestamp.now()});
const pet = (uid, id) => ({pet_id: id, owner_id: uid, name: 'cat', species: 'cat', breed: '',
  gender: '', birthday: '', personality: '', avatar_url: '', color: '', weight: 4,
  created_at: Timestamp.now(), updated_at: serverTimestamp()});
const reading = id => ({petId: id, title: 'title', content: 'private', mood: null, source: null,
  createdAt: '2026-09-08T00:00:00.000Z', updatedAt: null});
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-pawlink-security',
    firestore: {host: '127.0.0.1', port: 8180, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')},
    storage: {host: '127.0.0.1', port: 9299, rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8')},
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/a'), user('a'));
    await setDoc(doc(context.firestore(), 'users/b'), user('b'));
  });
});
test('owner access succeeds while anonymous and cross-account access fail', async () => {
  const a = env.authenticatedContext('a').firestore();
  const b = env.authenticatedContext('b').firestore();
  await assertSucceeds(setDoc(doc(a, 'pets/p'), pet('a', 'p')));
  await assertSucceeds(getDoc(doc(a, 'pets/p')));
  await assertFails(getDoc(doc(b, 'pets/p')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'pets/p')));
  await assertSucceeds(getDocs(query(collection(a, 'pets'), where('owner_id', '==', 'a'))));
  await assertFails(getDocs(collection(a, 'pets')));
  await assertFails(updateDoc(doc(a, 'pets/p'), {owner_id: 'b', updated_at: serverTimestamp()}));
  await assertFails(deleteDoc(doc(a, 'pets/p')));
  await assertSucceeds(setDoc(doc(a, 'pets/p/readings/r'), reading('p')));
  await assertFails(getDoc(doc(b, 'pets/p/readings/r')));
});
test('new account can create a valid profile but cannot forge protected defaults', async () => {
  const c = env.authenticatedContext('c').firestore();
  await assertFails(setDoc(doc(c, 'users/c'), {...user('c'), points: 999}));
  await assertSucceeds(setDoc(doc(c, 'users/c'), user('c')));
  await assertSucceeds(setDoc(doc(c, 'pets/new-c'), pet('c', 'new-c')));
});
test('protected profile fields and malformed profile/pet/reading data are denied', async () => {
  const a = env.authenticatedContext('a').firestore();
  await assertFails(updateDoc(doc(a, 'users/a'), {points: 999}));
  await assertFails(updateDoc(doc(a, 'users/a'), {membershipTier: 'pro'}));
  await assertFails(updateDoc(doc(a, 'users/a'), {displayName: {bad: true}}));
  await assertFails(updateDoc(doc(a, 'users/a'), {hasCompletedOnboarding: 'yes'}));
  await assertSucceeds(updateDoc(doc(a, 'users/a'), {displayName: 'updated'}));
  await assertFails(setDoc(doc(a, 'pets/p'), {...pet('a', 'p'), weight: 'bad'}));
  await assertSucceeds(setDoc(doc(a, 'pets/p'), pet('a', 'p')));
  await assertFails(setDoc(doc(a, 'pets/p/readings/r'), {...reading('p'), content: {bad: true}}));
  await assertFails(updateDoc(doc(a, 'pets/p'), {created_at: Timestamp.fromMillis(1), updated_at: serverTimestamp()}));
});
test('pet deletion marker freezes pet and child writes', async () => {
  const a = env.authenticatedContext('a').firestore();
  await setDoc(doc(a, 'pets/p'), pet('a', 'p'));
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'petTombstones/p'), {owner_id: 'a'}));
  await assertFails(updateDoc(doc(a, 'pets/p'), {name: 'late', updated_at: serverTimestamp()}));
  await assertFails(setDoc(doc(a, 'pets/p/readings/r'), reading('p')));
  await env.withSecurityRulesDisabled(c => deleteDoc(doc(c.firestore(), 'pets/p')));
  await assertFails(setDoc(doc(a, 'pets/p'), pet('a', 'p')));
});
test('account deletion marker blocks all writes using the still-authenticated session', async () => {
  const a = env.authenticatedContext('a').firestore();
  await setDoc(doc(a, 'pets/p'), pet('a', 'p'));
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), '_deletedUsers/a'), {deletedAt: Timestamp.now()}));
  await assertFails(setDoc(doc(a, 'pets/new'), pet('a', 'new')));
  await assertFails(updateDoc(doc(a, 'pets/p'), {name: 'late', updated_at: serverTimestamp()}));
  await assertFails(setDoc(doc(a, 'pets/p/readings/r'), reading('p')));
  await assertFails(updateDoc(doc(a, 'users/a'), {displayName: 'late'}));
  await assertFails(getDoc(doc(a, 'pets/p')));
  await env.withSecurityRulesDisabled(c => deleteDoc(doc(c.firestore(), 'users/a')));
  await assertFails(setDoc(doc(a, 'users/a'), user('a')));
});
test('Storage owner, MIME, size and deleted-account policy', async () => {
  const a = env.authenticatedContext('a').storage();
  const b = env.authenticatedContext('b').storage();
  await assertSucceeds(uploadBytes(ref(a, 'pets/a/avatar.png'), new Uint8Array([137,80,78,71]), {contentType: 'image/png'}));
  await assertFails(getBytes(ref(b, 'pets/a/avatar.png')));
  await assertFails(uploadBytes(ref(b, 'pets/a/avatar.png'), new Uint8Array([1]), {contentType: 'image/png'}));
  await assertFails(uploadBytes(ref(a, 'pets/a/bad.png'), new Uint8Array([1]), {contentType: 'text/html'}));
  await assertFails(uploadBytes(ref(a, 'pets/a/large.png'), new Uint8Array(10 * 1024 * 1024 + 1), {contentType: 'image/png'}));
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), '_deletedUsers/a'), {deletedAt: Timestamp.now()}));
  await assertFails(uploadBytes(ref(a, 'pets/a/late.png'), new Uint8Array([1]), {contentType: 'image/png'}));
  await assertFails(getBytes(ref(a, 'pets/a/avatar.png')));
});
