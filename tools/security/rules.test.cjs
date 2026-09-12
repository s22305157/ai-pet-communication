const {test, before, after, beforeEach} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, getDocs, collection, query, where, updateDoc, deleteDoc, serverTimestamp, Timestamp} = require('firebase/firestore');
const {ref, uploadBytes, getBytes, deleteObject} = require('firebase/storage');
let env;

test('communication photos enforce paid ownership, three immutable slots and 10 MB', async () => {
  const a = env.authenticatedContext('a').storage();
  const b = env.authenticatedContext('b').storage();
  const root = 'communicationPhotos/a/photo-request-00001';
  const put = (storage, slot, bytes = new Uint8Array([1]), contentType = 'image/png') =>
    uploadBytes(ref(storage, `${root}/${slot}`), bytes, {contentType});
  for (const slot of [0, 1, 2]) await assertSucceeds(put(a, slot));
  await assertFails(put(a, 3));
  await assertFails(put(a, 0));
  await assertFails(getBytes(ref(b, `${root}/0`)));
  await assertFails(put(b, 0));
  await assertFails(put(env.unauthenticatedContext().storage(), 0));
  await assertSucceeds(deleteObject(ref(a, `${root}/2`)));
  await assertFails(put(a, 2, new Uint8Array(10 * 1024 * 1024 + 1)));
  await assertFails(put(a, 2, new Uint8Array([1]), 'text/html'));
  await assertSucceeds(put(a, 2, new Uint8Array(10 * 1024 * 1024)));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'users/a'), {
    membershipEntitlements: {pro: Timestamp.fromMillis(1)},
  }));
  await assertSucceeds(deleteObject(ref(a, `${root}/2`)));
  await assertFails(put(a, 2));
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), '_deletedUsers/a'), {deletedAt: serverTimestamp()}));
  await assertFails(getBytes(ref(a, `${root}/0`)));
});
test('planet collection is owner-readable and server-write-only', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/a/planetCards/020'), {cardId: '020'});
  });
  const a = env.authenticatedContext('a').firestore();
  await assertSucceeds(getDocs(collection(a, 'users/a/planetCards')));
  await assertFails(getDoc(doc(env.authenticatedContext('b').firestore(), 'users/a/planetCards/020')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/a/planetCards/020')));
  await assertFails(setDoc(doc(a, 'users/a/planetCards/001'), {cardId: '001'}));
  await assertFails(updateDoc(doc(a, 'users/a/planetCards/020'), {cardId: '001'}));
  await assertFails(deleteDoc(doc(a, 'users/a/planetCards/020')));
});
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
    const paid = {membershipTier: 'pro', subscriptionVerified: true,
      membershipEntitlements: {pro: Timestamp.fromMillis(Date.now() + 3600000)}};
    await setDoc(doc(context.firestore(), 'users/a'), {...user('a'), ...paid});
    await setDoc(doc(context.firestore(), 'users/b'), {...user('b'), ...paid});
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
  await assertFails(setDoc(doc(c, 'pets/new-c'), pet('c', 'new-c')));
});
test('protected profile fields and malformed profile/pet/reading data are denied', async () => {
  const a = env.authenticatedContext('a').firestore();
  await assertFails(updateDoc(doc(a, 'users/a'), {points: 999}));
  await assertFails(updateDoc(doc(a, 'users/a'), {membershipTier: 'plus'}));
  await assertFails(updateDoc(doc(a, 'users/a'), {subscriptionVerified: false}));
  await assertFails(updateDoc(doc(a, 'users/a'), {manualMembershipEntitlements: {pro: Timestamp.fromMillis(Date.now() + 99999999)}}));
  await assertFails(updateDoc(doc(a, 'users/a'), {subscriptionProviderSyncDisabled: true}));
  await assertFails(updateDoc(doc(a, 'users/a'), {membershipEntitlements: {pro: Timestamp.fromMillis(Date.now() + 99999999)}}));
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

test('expired paid member keeps archive reads/deletes but cannot sync or forge renewal', async () => {
  const a = env.authenticatedContext('a').firestore();
  const storage = env.authenticatedContext('a').storage();
  await setDoc(doc(a, 'pets/p'), pet('a', 'p'));
  await setDoc(doc(a, 'pets/p/readings/r'), reading('p'));
  await uploadBytes(ref(storage, 'pets/a/avatar.png'), new Uint8Array([137,80,78,71]), {contentType: 'image/png'});
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'users/a'), {
    membershipTier: 'pro', membershipEntitlements: {pro: Timestamp.fromMillis(1)},
  }));
  await assertSucceeds(getDoc(doc(a, 'pets/p')));
  await assertSucceeds(getDoc(doc(a, 'pets/p/readings/r')));
  await assertSucceeds(getBytes(ref(storage, 'pets/a/avatar.png')));
  await assertFails(setDoc(doc(a, 'pets/new'), pet('a', 'new')));
  await assertFails(updateDoc(doc(a, 'pets/p'), {name: 'expired', updated_at: serverTimestamp()}));
  await assertFails(setDoc(doc(a, 'pets/p/readings/new'), reading('p')));
  await assertFails(uploadBytes(ref(storage, 'pets/a/new.png'), new Uint8Array([1]), {contentType: 'image/png'}));
  await assertFails(updateDoc(doc(a, 'users/a'), {membershipEntitlements: {pro: Timestamp.fromMillis(Date.now() + 999999)}}));
  await assertSucceeds(deleteDoc(doc(a, 'pets/p/readings/r')));
});

test('legacy unverified Pro is denied cloud writes; still-active Plus survives Pro expiry', async () => {
  const a = env.authenticatedContext('a').firestore();
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'users/a'), {...user('a'), membershipTier: 'pro'}));
  await assertFails(setDoc(doc(a, 'pets/p'), pet('a', 'p')));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'users/a'), {
    subscriptionVerified: true, membershipEntitlements: {pro: Timestamp.fromMillis(1), plus: Timestamp.fromMillis(Date.now() + 3600000)},
  }));
  await assertSucceeds(setDoc(doc(a, 'pets/p'), pet('a', 'p')));
});
