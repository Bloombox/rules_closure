
/* global goog */

goog.provide('ui.xid');
goog.provide('xid');


/**
 * Mock rewrite function for IDs.
 *
 * @param {!string} identifier Identifier to process or otherwise transform.
 * @returns {!string} Transformed identifier.
 */
const xid = function(identifier) {
  return identifier;
};


/**
 * Mock rewrite function for IDs.
 *
 * @param {!string} identifier Identifier to process or otherwise transform.
 * @returns {!string} Transformed identifier.
 */
ui.xid = function(identifier) {
  return xid(identifier);
};
