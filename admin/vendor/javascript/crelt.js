// crelt@1.0.6 downloaded from https://ga.jspm.io/npm:crelt@1.0.6/index.js

function crelt(){var e=arguments[0];"string"==typeof e&&(e=document.createElement(e));var r=1,t=arguments[1];if(t&&"object"==typeof t&&null==t.nodeType&&!Array.isArray(t)){for(var n in t)if(Object.prototype.hasOwnProperty.call(t,n)){var o=t[n];"string"==typeof o?e.setAttribute(n,o):null!=o&&(e[n]=o)}r++}for(;r<arguments.length;r++)add(e,arguments[r]);return e}function add(e,r){if("string"==typeof r)e.appendChild(document.createTextNode(r));else if(null==r);else if(null!=r.nodeType)e.appendChild(r);else{if(!Array.isArray(r))throw new RangeError("Unsupported child node: "+r);for(var t=0;t<r.length;t++)add(e,r[t])}}export{crelt as default};

