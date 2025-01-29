// lodash/debounce.js@4.17.21 downloaded from https://ga.jspm.io/npm:lodash@4.17.21/debounce.js

import e from"./isObject.js";import i from"./now.js";import n from"./toNumber.js";import"./_/b15bba73.js";import"./_/83742462.js";import"./_/69d56582.js";import"./isSymbol.js";import"./_/052e9e66.js";import"./_/e65ed236.js";import"./isObjectLike.js";var r="undefined"!==typeof globalThis?globalThis:"undefined"!==typeof self?self:global;var t={};var o=e,u=i,a=n;var d="Expected a function";var f=Math.max,c=Math.min;
/**
 * Creates a debounced function that delays invoking `func` until after `wait`
 * milliseconds have elapsed since the last time the debounced function was
 * invoked. The debounced function comes with a `cancel` method to cancel
 * delayed `func` invocations and a `flush` method to immediately invoke them.
 * Provide `options` to indicate whether `func` should be invoked on the
 * leading and/or trailing edge of the `wait` timeout. The `func` is invoked
 * with the last arguments provided to the debounced function. Subsequent
 * calls to the debounced function return the result of the last `func`
 * invocation.
 *
 * **Note:** If `leading` and `trailing` options are `true`, `func` is
 * invoked on the trailing edge of the timeout only if the debounced function
 * is invoked more than once during the `wait` timeout.
 *
 * If `wait` is `0` and `leading` is `false`, `func` invocation is deferred
 * until to the next tick, similar to `setTimeout` with a timeout of `0`.
 *
 * See [David Corbacho's article](https://css-tricks.com/debouncing-throttling-explained-examples/)
 * for details over the differences between `_.debounce` and `_.throttle`.
 *
 * @static
 * @memberOf _
 * @since 0.1.0
 * @category Function
 * @param {Function} func The function to debounce.
 * @param {number} [wait=0] The number of milliseconds to delay.
 * @param {Object} [options={}] The options object.
 * @param {boolean} [options.leading=false]
 *  Specify invoking on the leading edge of the timeout.
 * @param {number} [options.maxWait]
 *  The maximum time `func` is allowed to be delayed before it's invoked.
 * @param {boolean} [options.trailing=true]
 *  Specify invoking on the trailing edge of the timeout.
 * @returns {Function} Returns the new debounced function.
 * @example
 *
 * // Avoid costly calculations while the window size is in flux.
 * jQuery(window).on('resize', _.debounce(calculateLayout, 150));
 *
 * // Invoke `sendMail` when clicked, debouncing subsequent calls.
 * jQuery(element).on('click', _.debounce(sendMail, 300, {
 *   'leading': true,
 *   'trailing': false
 * }));
 *
 * // Ensure `batchLog` is invoked once after 1 second of debounced calls.
 * var debounced = _.debounce(batchLog, 250, { 'maxWait': 1000 });
 * var source = new EventSource('/stream');
 * jQuery(source).on('message', debounced);
 *
 * // Cancel the trailing debounced invocation.
 * jQuery(window).on('popstate', debounced.cancel);
 */function debounce(e,i,n){var t,l,m,s,v,p,g=0,b=false,h=false,j=true;if("function"!=typeof e)throw new TypeError(d);i=a(i)||0;if(o(n)){b=!!n.leading;h="maxWait"in n;m=h?f(a(n.maxWait)||0,i):m;j="trailing"in n?!!n.trailing:j}function invokeFunc(i){var n=t,r=l;t=l=void 0;g=i;s=e.apply(r,n);return s}function leadingEdge(e){g=e;v=setTimeout(timerExpired,i);return b?invokeFunc(e):s}function remainingWait(e){var n=e-p,r=e-g,t=i-n;return h?c(t,m-r):t}function shouldInvoke(e){var n=e-p,r=e-g;return void 0===p||n>=i||n<0||h&&r>=m}function timerExpired(){var e=u();if(shouldInvoke(e))return trailingEdge(e);v=setTimeout(timerExpired,remainingWait(e))}function trailingEdge(e){v=void 0;if(j&&t)return invokeFunc(e);t=l=void 0;return s}function cancel(){void 0!==v&&clearTimeout(v);g=0;t=p=l=v=void 0}function flush(){return void 0===v?s:trailingEdge(u())}function debounced(){var e=u(),n=shouldInvoke(e);t=arguments;l=this||r;p=e;if(n){if(void 0===v)return leadingEdge(p);if(h){clearTimeout(v);v=setTimeout(timerExpired,i);return invokeFunc(p)}}void 0===v&&(v=setTimeout(timerExpired,i));return s}debounced.cancel=cancel;debounced.flush=flush;return debounced}t=debounce;var l=t;export{l as default};

