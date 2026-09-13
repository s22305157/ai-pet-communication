const {createJournalContext} = require('./journal_context');
const {endpointNames} = require('./endpoints');
const P = require('./journal_policy');

function createJournalService(options) {
  const context = createJournalContext(options);
  const handlers = {};
  const shared = {...context, handlers};
  const loaded = {};
  const once = (name, factory) => () => {
    if (!Object.hasOwn(loaded, name)) loaded[name] = factory();
    return loaded[name];
  };
  const journal = once('journal', () => require('./journal_feature_service')({
    ...shared, normalize: options.normalize ?? P.normalizeImage}));
  const pilot = once('pilot', () => require('./journal_pilot_service')(shared));
  const metrics = once('metrics', () => require('./pilot_metrics_service')({
    ...shared, metricAdminIds: options.metricAdminIds}));
  const reviews = once('reviews', () => require('./weekly_review_service')({
    ...shared, reviewProvider: options.reviewProvider}));
  const community = once('community', () => require('./community_service')(shared));
  const cleanup = once('cleanup', () => require('./journal_cleanup_service')({
    ...shared, community: {cleanupSource: (...args) => community().cleanupSource(...args)}}));
  const pilotNames = new Set(['getPilotAccess', 'activatePilot', 'adminSetPilotParticipant']);
  const metricsNames = new Set(['getPilotInterest', 'markPilotPriceViewed', 'setPilotInterest',
    'setPilotMetricsConsent', 'adminGetPilotMetrics', 'adminSetPilotCost', 'adminGetPilotCost']);
  const journalNames = new Set(require('./endpoints/journal'));
  const reviewNames = new Set(require('./endpoints/weekly_review'));
  const publicHandlers = {};
  for (const name of endpointNames) {
    // Only resolve the requested feature. Authentication and idempotency share
    // one context; loading a journal callable does not construct every service.
    Object.defineProperty(publicHandlers, name, {enumerable: true, get() {
      if (name === 'deleteJournalPet') cleanup();
      else if (journalNames.has(name)) journal();
      else if (pilotNames.has(name)) pilot();
      else if (metricsNames.has(name)) metrics();
      else if (reviewNames.has(name)) reviews();
      else community();
      if (typeof handlers[name] !== 'function') throw Error('Missing handler for ' + name);
      return handlers[name];
    }});
  }
  return {handlers: publicHandlers,
    sweep: async () => { await cleanup().sweep(); await community().sweep(); await metrics().sweep(); },
    markPetDeleted: (...args) => cleanup().markPetDeleted(...args),
    cleanupPet: (...args) => cleanup().cleanupPet(...args),
    get reviews() { return reviews(); }, get community() { return community(); }};
}
module.exports = {createJournalService};
