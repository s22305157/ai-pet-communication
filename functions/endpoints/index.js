const groups = Object.freeze({
  journal: require('./journal'),
  community: require('./community'),
  weeklyReview: require('./weekly_review'),
  pilot: require('./pilot'),
});
const endpointNames = Object.freeze(Object.values(groups).flat());
if (new Set(endpointNames).size !== endpointNames.length) {
  throw new Error('A callable is registered by more than one feature');
}

function assertEndpointHandlers(handlers) {
  for (const name of endpointNames) {
    if (typeof handlers[name] !== 'function') {
      throw new Error(`Missing handler for ${name}`);
    }
  }
}

module.exports = {groups, endpointNames, assertEndpointHandlers};
