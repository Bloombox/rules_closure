
/* global goog */

goog.provide('xid');


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
