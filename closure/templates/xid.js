
/* global goog */

goog.provide('xid');
goog.provide('ui.xid');


/**
 * Base XID function, which rewrites CSS IDs. This function is provided for Soy templates which demand
 * an ID function to generate template instance IDs.
 *
 * @idGenerator {xid}
 * @param {!string} identifier Identifier to process or otherwise transform.
 * @returns {!string} Transformed identifier.
 */
const xid = function(identifier) {
  return identifier;
};


/**
 * Alias for the base XID function.
 *
 * @public
 */
ui.xid = xid;
