// lodash/merge@4.17.21 downloaded from https://ga.jspm.io/npm:lodash@4.17.21/merge.js

import{_ as s}from"./_/3a21c86a.js";import{_ as i}from"./_/d7952e2b.js";import"./_Stack.js";import"./_/9e9ce10f.js";import"./_/70a2d34d.js";import"./_/58273e1c.js";import"./isFunction.js";import"./_/052e9e66.js";import"./_/e65ed236.js";import"./_/b15bba73.js";import"./isObject.js";import"./eq.js";import"./_/38d0670d.js";import"./_/762679ff.js";import"./_/d35a7fd6.js";import"./_/d603d993.js";import"./_/ae1a03d5.js";import"./_cloneBuffer.js";import"./_/38f90d17.js";import"./_/8ae180c0.js";import"./_copyArray.js";import"./_initCloneObject.js";import"./_/79ae4a01.js";import"./_/ca1e037e.js";import"./_/d2b8ecf6.js";import"./_/1d469fdd.js";import"./isArguments.js";import"./isObjectLike.js";import"./isArray.js";import"./isArrayLikeObject.js";import"./isArrayLike.js";import"./isLength.js";import"./isBuffer.js";import"./stubFalse.js";import"./isPlainObject.js";import"./isTypedArray.js";import"./_/dcdb9fca.js";import"./_/9f64fdae.js";import"./toPlainObject.js";import"./_/b1449f65.js";import"./_assignValue.js";import"./keysIn.js";import"./_/d533f765.js";import"./_/c8441f51.js";import"./_isIndex.js";import"./_baseRest.js";import"./identity.js";import"./_overRest.js";import"./_apply.js";import"./_/ead8ed36.js";import"./constant.js";import"./_/7781ca7a.js";var t={};var r=s,o=i;
/**
 * This method is like `_.assign` except that it recursively merges own and
 * inherited enumerable string keyed properties of source objects into the
 * destination object. Source properties that resolve to `undefined` are
 * skipped if a destination value exists. Array and plain object properties
 * are merged recursively. Other objects and value types are overridden by
 * assignment. Source objects are applied from left to right. Subsequent
 * sources overwrite property assignments of previous sources.
 *
 * **Note:** This method mutates `object`.
 *
 * @static
 * @memberOf _
 * @since 0.5.0
 * @category Object
 * @param {Object} object The destination object.
 * @param {...Object} [sources] The source objects.
 * @returns {Object} Returns `object`.
 * @example
 *
 * var object = {
 *   'a': [{ 'b': 2 }, { 'd': 4 }]
 * };
 *
 * var other = {
 *   'a': [{ 'c': 3 }, { 'e': 5 }]
 * };
 *
 * _.merge(object, other);
 * // => { 'a': [{ 'b': 2, 'c': 3 }, { 'd': 4, 'e': 5 }] }
 */var j=o((function(s,i,t){r(s,i,t)}));t=j;var p=t;export{p as default};

