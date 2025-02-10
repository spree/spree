// photoswipe@5.4.4 downloaded from https://ga.jspm.io/npm:photoswipe@5.4.4/dist/photoswipe.esm.js

/** @typedef {import('../photoswipe.js').Point} Point */
/**
 * @template {keyof HTMLElementTagNameMap} T
 * @param {string} className
 * @param {T} tagName
 * @param {Node} [appendToEl]
 * @returns {HTMLElementTagNameMap[T]}
 */
function createElement(t,e,i){const s=document.createElement(e);t&&(s.className=t);i&&i.appendChild(s);return s}
/**
 * @param {Point} p1
 * @param {Point} p2
 * @returns {Point}
 */function equalizePoints(t,e){t.x=e.x;t.y=e.y;e.id!==void 0&&(t.id=e.id);return t}
/**
 * @param {Point} p
 */function roundPoint(t){t.x=Math.round(t.x);t.y=Math.round(t.y)}
/**
 * Returns distance between two points.
 *
 * @param {Point} p1
 * @param {Point} p2
 * @returns {number}
 */function getDistanceBetween(t,e){const i=Math.abs(t.x-e.x);const s=Math.abs(t.y-e.y);return Math.sqrt(i*i+s*s)}
/**
 * Whether X and Y positions of points are equal
 *
 * @param {Point} p1
 * @param {Point} p2
 * @returns {boolean}
 */function pointsEqual(t,e){return t.x===e.x&&t.y===e.y}
/**
 * The float result between the min and max values.
 *
 * @param {number} val
 * @param {number} min
 * @param {number} max
 * @returns {number}
 */function clamp(t,e,i){return Math.min(Math.max(t,e),i)}
/**
 * Get transform string
 *
 * @param {number} x
 * @param {number} [y]
 * @param {number} [scale]
 * @returns {string}
 */function toTransformString(t,e,i){let s=`translate3d(${t}px,${e||0}px,0)`;i!==void 0&&(s+=` scale3d(${i},${i},1)`);return s}
/**
 * Apply transform:translate(x, y) scale(scale) to element
 *
 * @param {HTMLElement} el
 * @param {number} x
 * @param {number} [y]
 * @param {number} [scale]
 */function setTransform(t,e,i,s){t.style.transform=toTransformString(e,i,s)}const t="cubic-bezier(.4,0,.22,1)";
/**
 * Apply CSS transition to element
 *
 * @param {HTMLElement} el
 * @param {string} [prop] CSS property to animate
 * @param {number} [duration] in ms
 * @param {string} [ease] CSS easing function
 */function setTransitionStyle(e,i,s,n){e.style.transition=i?`${i} ${s}ms ${n||t}`:"none"}
/**
 * Apply width and height CSS properties to element
 *
 * @param {HTMLElement} el
 * @param {string | number} w
 * @param {string | number} h
 */function setWidthHeight(t,e,i){t.style.width=typeof e==="number"?`${e}px`:e;t.style.height=typeof i==="number"?`${i}px`:i}
/**
 * @param {HTMLElement} el
 */function removeTransitionStyle(t){setTransitionStyle(t)}
/**
 * @param {HTMLImageElement} img
 * @returns {Promise<HTMLImageElement | void>}
 */function decodeImage(t){return"decode"in t?t.decode().catch((()=>{})):t.complete?Promise.resolve(t):new Promise(((e,i)=>{t.onload=()=>e(t);t.onerror=i}))}
/** @typedef {LOAD_STATE[keyof LOAD_STATE]} LoadState */
/** @type {{ IDLE: 'idle'; LOADING: 'loading'; LOADED: 'loaded'; ERROR: 'error' }} */const e={IDLE:"idle",LOADING:"loading",LOADED:"loaded",ERROR:"error"};
/**
 * Check if click or keydown event was dispatched
 * with a special key or via mouse wheel.
 *
 * @param {MouseEvent | KeyboardEvent} e
 * @returns {boolean}
 */function specialKeyUsed(t){return"button"in t&&t.button===1||t.ctrlKey||t.metaKey||t.altKey||t.shiftKey}
/**
 * Parse `gallery` or `children` options.
 *
 * @param {import('../photoswipe.js').ElementProvider} [option]
 * @param {string} [legacySelector]
 * @param {HTMLElement | Document} [parent]
 * @returns HTMLElement[]
 */function getElementsFromOption(t,e,i=document){
/** @type {HTMLElement[]} */
let s=[];if(t instanceof Element)s=[t];else if(t instanceof NodeList||Array.isArray(t))s=Array.from(t);else{const n=typeof t==="string"?t:e;n&&(s=Array.from(i.querySelectorAll(n)))}return s}
/**
 * Check if browser is Safari
 *
 * @returns {boolean}
 */function isSafari(){return!!(navigator.vendor&&navigator.vendor.match(/apple/i))}let i=false;try{window.addEventListener("test",null,Object.defineProperty({},"passive",{get:()=>{i=true}}))}catch(t){}
/**
 * @typedef {Object} PoolItem
 * @prop {HTMLElement | Window | Document | undefined | null} target
 * @prop {string} type
 * @prop {EventListenerOrEventListenerObject} listener
 * @prop {boolean} [passive]
 */class DOMEvents{constructor(){
/**
     * @type {PoolItem[]}
     * @private
     */
this._pool=[]}
/**
   * Adds event listeners
   *
   * @param {PoolItem['target']} target
   * @param {PoolItem['type']} type Can be multiple, separated by space.
   * @param {PoolItem['listener']} listener
   * @param {PoolItem['passive']} [passive]
   */add(t,e,i,s){this._toggleListener(t,e,i,s)}
/**
   * Removes event listeners
   *
   * @param {PoolItem['target']} target
   * @param {PoolItem['type']} type
   * @param {PoolItem['listener']} listener
   * @param {PoolItem['passive']} [passive]
   */remove(t,e,i,s){this._toggleListener(t,e,i,s,true)}removeAll(){this._pool.forEach((t=>{this._toggleListener(t.target,t.type,t.listener,t.passive,true,true)}));this._pool=[]}
/**
   * Adds or removes event
   *
   * @private
   * @param {PoolItem['target']} target
   * @param {PoolItem['type']} type
   * @param {PoolItem['listener']} listener
   * @param {PoolItem['passive']} [passive]
   * @param {boolean} [unbind] Whether the event should be added or removed
   * @param {boolean} [skipPool] Whether events pool should be skipped
   */_toggleListener(t,e,s,n,o,a){if(!t)return;const r=o?"removeEventListener":"addEventListener";const h=e.split(" ");h.forEach((e=>{if(e){a||(o?this._pool=this._pool.filter((i=>i.type!==e||i.listener!==s||i.target!==t)):this._pool.push({target:t,type:e,listener:s,passive:n}));const h=!!i&&{passive:n||false};t[r](e,s,h)}}))}}
/** @typedef {import('../photoswipe.js').PhotoSwipeOptions} PhotoSwipeOptions */
/** @typedef {import('../core/base.js').default} PhotoSwipeBase */
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {import('../slide/slide.js').SlideData} SlideData */
/**
 * @param {PhotoSwipeOptions} options
 * @param {PhotoSwipeBase} pswp
 * @returns {Point}
 */function getViewportSize(t,e){if(t.getViewportSizeFn){const i=t.getViewportSizeFn(t,e);if(i)return i}return{x:document.documentElement.clientWidth,y:window.innerHeight}}
/**
 * Parses padding option.
 * Supported formats:
 *
 * // Object
 * padding: {
 *  top: 0,
 *  bottom: 0,
 *  left: 0,
 *  right: 0
 * }
 *
 * // A function that returns the object
 * paddingFn: (viewportSize, itemData, index) => {
 *  return {
 *    top: 0,
 *    bottom: 0,
 *    left: 0,
 *    right: 0
 *  };
 * }
 *
 * // Legacy variant
 * paddingLeft: 0,
 * paddingRight: 0,
 * paddingTop: 0,
 * paddingBottom: 0,
 *
 * @param {'left' | 'top' | 'bottom' | 'right'} prop
 * @param {PhotoSwipeOptions} options PhotoSwipe options
 * @param {Point} viewportSize PhotoSwipe viewport size, for example: { x:800, y:600 }
 * @param {SlideData} itemData Data about the slide
 * @param {number} index Slide index
 * @returns {number}
 */function parsePaddingOption(t,e,i,s,n){let o=0;if(e.paddingFn)o=e.paddingFn(i,s,n)[t];else if(e.padding)o=e.padding[t];else{const i="padding"+t[0].toUpperCase()+t.slice(1);e[i]&&(o=e[i])}return Number(o)||0}
/**
 * @param {PhotoSwipeOptions} options
 * @param {Point} viewportSize
 * @param {SlideData} itemData
 * @param {number} index
 * @returns {Point}
 */function getPanAreaSize(t,e,i,s){return{x:e.x-parsePaddingOption("left",t,e,i,s)-parsePaddingOption("right",t,e,i,s),y:e.y-parsePaddingOption("top",t,e,i,s)-parsePaddingOption("bottom",t,e,i,s)}}
/** @typedef {import('./slide.js').default} Slide */
/** @typedef {Record<Axis, number>} Point */
/** @typedef {'x' | 'y'} Axis */class PanBounds{
/**
   * @param {Slide} slide
   */
constructor(t){this.slide=t;this.currZoomLevel=1;this.center=
/** @type {Point} */
{x:0,y:0};this.max=
/** @type {Point} */
{x:0,y:0};this.min=
/** @type {Point} */
{x:0,y:0}}
/**
   * _getItemBounds
   *
   * @param {number} currZoomLevel
   */update(t){this.currZoomLevel=t;if(this.slide.width){this._updateAxis("x");this._updateAxis("y");this.slide.pswp.dispatch("calcBounds",{slide:this.slide})}else this.reset()}
/**
   * _calculateItemBoundsForAxis
   *
   * @param {Axis} axis
   */_updateAxis(t){const{pswp:e}=this.slide;const i=this.slide[t==="x"?"width":"height"]*this.currZoomLevel;const s=t==="x"?"left":"top";const n=parsePaddingOption(s,e.options,e.viewportSize,this.slide.data,this.slide.index);const o=this.slide.panAreaSize[t];this.center[t]=Math.round((o-i)/2)+n;this.max[t]=i>o?Math.round(o-i)+n:this.center[t];this.min[t]=i>o?n:this.center[t]}reset(){this.center.x=0;this.center.y=0;this.max.x=0;this.max.y=0;this.min.x=0;this.min.y=0}
/**
   * Correct pan position if it's beyond the bounds
   *
   * @param {Axis} axis x or y
   * @param {number} panOffset
   * @returns {number}
   */correctPan(t,e){return clamp(e,this.max[t],this.min[t])}}const s=4e3;
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/** @typedef {import('../photoswipe.js').PhotoSwipeOptions} PhotoSwipeOptions */
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {import('../slide/slide.js').SlideData} SlideData */
/** @typedef {'fit' | 'fill' | number | ((zoomLevelObject: ZoomLevel) => number)} ZoomLevelOption */class ZoomLevel{
/**
   * @param {PhotoSwipeOptions} options PhotoSwipe options
   * @param {SlideData} itemData Slide data
   * @param {number} index Slide index
   * @param {PhotoSwipe} [pswp] PhotoSwipe instance, can be undefined if not initialized yet
   */
constructor(t,e,i,s){this.pswp=s;this.options=t;this.itemData=e;this.index=i;
/** @type { Point | null } */this.panAreaSize=null;
/** @type { Point | null } */this.elementSize=null;this.fit=1;this.fill=1;this.vFill=1;this.initial=1;this.secondary=1;this.max=1;this.min=1}
/**
   * Calculate initial, secondary and maximum zoom level for the specified slide.
   *
   * It should be called when either image or viewport size changes.
   *
   * @param {number} maxWidth
   * @param {number} maxHeight
   * @param {Point} panAreaSize
   */update(t,e,i){
/** @type {Point} */
const s={x:t,y:e};this.elementSize=s;this.panAreaSize=i;const n=i.x/s.x;const o=i.y/s.y;this.fit=Math.min(1,n<o?n:o);this.fill=Math.min(1,n>o?n:o);this.vFill=Math.min(1,o);this.initial=this._getInitial();this.secondary=this._getSecondary();this.max=Math.max(this.initial,this.secondary,this._getMax());this.min=Math.min(this.fit,this.initial,this.secondary);this.pswp&&this.pswp.dispatch("zoomLevelsUpdate",{zoomLevels:this,slideData:this.itemData})}
/**
   * Parses user-defined zoom option.
   *
   * @private
   * @param {'initial' | 'secondary' | 'max'} optionPrefix Zoom level option prefix (initial, secondary, max)
   * @returns { number | undefined }
   */_parseZoomLevelOption(t){const e=
/** @type {'initialZoomLevel' | 'secondaryZoomLevel' | 'maxZoomLevel'} */
t+"ZoomLevel";const i=this.options[e];if(i)return typeof i==="function"?i(this):i==="fill"?this.fill:i==="fit"?this.fit:Number(i)}_getSecondary(){let t=this._parseZoomLevelOption("secondary");if(t)return t;t=Math.min(1,this.fit*3);this.elementSize&&t*this.elementSize.x>s&&(t=s/this.elementSize.x);return t}_getInitial(){return this._parseZoomLevelOption("initial")||this.fit}_getMax(){return this._parseZoomLevelOption("max")||Math.max(1,this.fit*4)}}
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */class Slide{
/**
   * @param {SlideData} data
   * @param {number} index
   * @param {PhotoSwipe} pswp
   */
constructor(t,e,i){this.data=t;this.index=e;this.pswp=i;this.isActive=e===i.currIndex;this.currentResolution=0;
/** @type {Point} */this.panAreaSize={x:0,y:0};
/** @type {Point} */this.pan={x:0,y:0};this.isFirstSlide=this.isActive&&!i.opener.isOpen;this.zoomLevels=new ZoomLevel(i.options,t,e,i);this.pswp.dispatch("gettingData",{slide:this,data:this.data,index:e});this.content=this.pswp.contentLoader.getContentBySlide(this);this.container=createElement("pswp__zoom-wrap","div");
/** @type {HTMLElement | null} */this.holderElement=null;this.currZoomLevel=1;
/** @type {number} */this.width=this.content.width;
/** @type {number} */this.height=this.content.height;this.heavyAppended=false;this.bounds=new PanBounds(this);this.prevDisplayedWidth=-1;this.prevDisplayedHeight=-1;this.pswp.dispatch("slideInit",{slide:this})}
/**
   * If this slide is active/current/visible
   *
   * @param {boolean} isActive
   */setIsActive(t){t&&!this.isActive?this.activate():!t&&this.isActive&&this.deactivate()}
/**
   * Appends slide content to DOM
   *
   * @param {HTMLElement} holderElement
   */append(t){this.holderElement=t;this.container.style.transformOrigin="0 0";if(this.data){this.calculateSize();this.load();this.updateContentSize();this.appendHeavy();this.holderElement.appendChild(this.container);this.zoomAndPanToInitial();this.pswp.dispatch("firstZoomPan",{slide:this});this.applyCurrentZoomPan();this.pswp.dispatch("afterSetContent",{slide:this});this.isActive&&this.activate()}}load(){this.content.load(false);this.pswp.dispatch("slideLoad",{slide:this})}appendHeavy(){const{pswp:t}=this;const e=true;if(!this.heavyAppended&&t.opener.isOpen&&!t.mainScroll.isShifted()&&(this.isActive||e)&&!this.pswp.dispatch("appendHeavy",{slide:this}).defaultPrevented){this.heavyAppended=true;this.content.append();this.pswp.dispatch("appendHeavyContent",{slide:this})}}activate(){this.isActive=true;this.appendHeavy();this.content.activate();this.pswp.dispatch("slideActivate",{slide:this})}deactivate(){this.isActive=false;this.content.deactivate();this.currZoomLevel!==this.zoomLevels.initial&&this.calculateSize();this.currentResolution=0;this.zoomAndPanToInitial();this.applyCurrentZoomPan();this.updateContentSize();this.pswp.dispatch("slideDeactivate",{slide:this})}destroy(){this.content.hasSlide=false;this.content.remove();this.container.remove();this.pswp.dispatch("slideDestroy",{slide:this})}resize(){if(this.currZoomLevel!==this.zoomLevels.initial&&this.isActive){this.calculateSize();this.bounds.update(this.currZoomLevel);this.panTo(this.pan.x,this.pan.y)}else{this.calculateSize();this.currentResolution=0;this.zoomAndPanToInitial();this.applyCurrentZoomPan();this.updateContentSize()}}
/**
   * Apply size to current slide content,
   * based on the current resolution and scale.
   *
   * @param {boolean} [force] if size should be updated even if dimensions weren't changed
   */updateContentSize(t){const e=this.currentResolution||this.zoomLevels.initial;if(!e)return;const i=Math.round(this.width*e)||this.pswp.viewportSize.x;const s=Math.round(this.height*e)||this.pswp.viewportSize.y;(this.sizeChanged(i,s)||t)&&this.content.setDisplayedSize(i,s)}
/**
   * @param {number} width
   * @param {number} height
   */sizeChanged(t,e){if(t!==this.prevDisplayedWidth||e!==this.prevDisplayedHeight){this.prevDisplayedWidth=t;this.prevDisplayedHeight=e;return true}return false}
/** @returns {HTMLImageElement | HTMLDivElement | null | undefined} */getPlaceholderElement(){var t;return(t=this.content.placeholder)===null||t===void 0?void 0:t.element}
/**
   * Zoom current slide image to...
   *
   * @param {number} destZoomLevel Destination zoom level.
   * @param {Point} [centerPoint]
   * Transform origin center point, or false if viewport center should be used.
   * @param {number | false} [transitionDuration] Transition duration, may be set to 0.
   * @param {boolean} [ignoreBounds] Minimum and maximum zoom levels will be ignored.
   */zoomTo(t,e,i,s){const{pswp:n}=this;if(!this.isZoomable()||n.mainScroll.isShifted())return;n.dispatch("beforeZoomTo",{destZoomLevel:t,centerPoint:e,transitionDuration:i});n.animations.stopAllPan();const o=this.currZoomLevel;s||(t=clamp(t,this.zoomLevels.min,this.zoomLevels.max));this.setZoomLevel(t);this.pan.x=this.calculateZoomToPanOffset("x",e,o);this.pan.y=this.calculateZoomToPanOffset("y",e,o);roundPoint(this.pan);const finishTransition=()=>{this._setResolution(t);this.applyCurrentZoomPan()};i?n.animations.startTransition({isPan:true,name:"zoomTo",target:this.container,transform:this.getCurrentTransform(),onComplete:finishTransition,duration:i,easing:n.options.easing}):finishTransition()}
/**
   * @param {Point} [centerPoint]
   */toggleZoom(t){this.zoomTo(this.currZoomLevel===this.zoomLevels.initial?this.zoomLevels.secondary:this.zoomLevels.initial,t,this.pswp.options.zoomAnimationDuration)}
/**
   * Updates zoom level property and recalculates new pan bounds,
   * unlike zoomTo it does not apply transform (use applyCurrentZoomPan)
   *
   * @param {number} currZoomLevel
   */setZoomLevel(t){this.currZoomLevel=t;this.bounds.update(this.currZoomLevel)}
/**
   * Get pan position after zoom at a given `point`.
   *
   * Always call setZoomLevel(newZoomLevel) beforehand to recalculate
   * pan bounds according to the new zoom level.
   *
   * @param {'x' | 'y'} axis
   * @param {Point} [point]
   * point based on which zoom is performed, usually refers to the current mouse position,
   * if false - viewport center will be used.
   * @param {number} [prevZoomLevel] Zoom level before new zoom was applied.
   * @returns {number}
   */calculateZoomToPanOffset(t,e,i){const s=this.bounds.max[t]-this.bounds.min[t];if(s===0)return this.bounds.center[t];e||(e=this.pswp.getViewportCenterPoint());i||(i=this.zoomLevels.initial);const n=this.currZoomLevel/i;return this.bounds.correctPan(t,(this.pan[t]-e[t])*n+e[t])}
/**
   * Apply pan and keep it within bounds.
   *
   * @param {number} panX
   * @param {number} panY
   */panTo(t,e){this.pan.x=this.bounds.correctPan("x",t);this.pan.y=this.bounds.correctPan("y",e);this.applyCurrentZoomPan()}
/**
   * If the slide in the current state can be panned by the user
   * @returns {boolean}
   */isPannable(){return Boolean(this.width)&&this.currZoomLevel>this.zoomLevels.fit}
/**
   * If the slide can be zoomed
   * @returns {boolean}
   */isZoomable(){return Boolean(this.width)&&this.content.isZoomable()}applyCurrentZoomPan(){this._applyZoomTransform(this.pan.x,this.pan.y,this.currZoomLevel);this===this.pswp.currSlide&&this.pswp.dispatch("zoomPanUpdate",{slide:this})}zoomAndPanToInitial(){this.currZoomLevel=this.zoomLevels.initial;this.bounds.update(this.currZoomLevel);equalizePoints(this.pan,this.bounds.center);this.pswp.dispatch("initialZoomPan",{slide:this})}
/**
   * Set translate and scale based on current resolution
   *
   * @param {number} x
   * @param {number} y
   * @param {number} zoom
   * @private
   */_applyZoomTransform(t,e,i){i/=this.currentResolution||this.zoomLevels.initial;setTransform(this.container,t,e,i)}calculateSize(){const{pswp:t}=this;equalizePoints(this.panAreaSize,getPanAreaSize(t.options,t.viewportSize,this.data,this.index));this.zoomLevels.update(this.width,this.height,this.panAreaSize);t.dispatch("calcSlideSize",{slide:this})}
/** @returns {string} */getCurrentTransform(){const t=this.currZoomLevel/(this.currentResolution||this.zoomLevels.initial);return toTransformString(this.pan.x,this.pan.y,t)}
/**
   * Set resolution and re-render the image.
   *
   * For example, if the real image size is 2000x1500,
   * and resolution is 0.5 - it will be rendered as 1000x750.
   *
   * Image with zoom level 2 and resolution 0.5 is
   * the same as image with zoom level 1 and resolution 1.
   *
   * Used to optimize animations and make
   * sure that browser renders image in the highest quality.
   * Also used by responsive images to load the correct one.
   *
   * @param {number} newResolution
   */_setResolution(t){if(t!==this.currentResolution){this.currentResolution=t;this.updateContentSize();this.pswp.dispatch("resolutionChanged")}}}
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {import('./gestures.js').default} Gestures */const n=.35;const o=.6;const a=.4;const r=.5;
/**
 * @param {number} initialVelocity
 * @param {number} decelerationRate
 * @returns {number}
 */function project(t,e){return t*e/(1-e)}class DragHandler{
/**
   * @param {Gestures} gestures
   */
constructor(t){this.gestures=t;this.pswp=t.pswp;
/** @type {Point} */this.startPan={x:0,y:0}}start(){this.pswp.currSlide&&equalizePoints(this.startPan,this.pswp.currSlide.pan);this.pswp.animations.stopAll()}change(){const{p1:t,prevP1:e,dragAxis:i}=this.gestures;const{currSlide:s}=this.pswp;if(i==="y"&&this.pswp.options.closeOnVerticalDrag&&s&&s.currZoomLevel<=s.zoomLevels.fit&&!this.gestures.isMultitouch){const i=s.pan.y+(t.y-e.y);if(!this.pswp.dispatch("verticalDrag",{panY:i}).defaultPrevented){this._setPanWithFriction("y",i,o);const t=1-Math.abs(this._getVerticalDragRatio(s.pan.y));this.pswp.applyBgOpacity(t);s.applyCurrentZoomPan()}}else{const t=this._panOrMoveMainScroll("x");if(!t){this._panOrMoveMainScroll("y");if(s){roundPoint(s.pan);s.applyCurrentZoomPan()}}}}end(){const{velocity:t}=this.gestures;const{mainScroll:e,currSlide:i}=this.pswp;let s=0;this.pswp.animations.stopAll();if(e.isShifted()){const i=e.x-e.getCurrSlideX();const n=i/this.pswp.viewportSize.x;if(t.x<-r&&n<0||t.x<.1&&n<-.5){s=1;t.x=Math.min(t.x,0)}else if(t.x>r&&n>0||t.x>-.1&&n>.5){s=-1;t.x=Math.max(t.x,0)}e.moveIndexBy(s,true,t.x)}if(i&&i.currZoomLevel>i.zoomLevels.max||this.gestures.isMultitouch)this.gestures.zoomLevels.correctZoomPan(true);else{this._finishPanGestureForAxis("x");this._finishPanGestureForAxis("y")}}
/**
   * @private
   * @param {'x' | 'y'} axis
   */_finishPanGestureForAxis(t){const{velocity:e}=this.gestures;const{currSlide:i}=this.pswp;if(!i)return;const{pan:s,bounds:n}=i;const o=s[t];const r=this.pswp.bgOpacity<1&&t==="y";const h=.995;const l=o+project(e[t],h);if(r){const t=this._getVerticalDragRatio(o);const e=this._getVerticalDragRatio(l);if(t<0&&e<-a||t>0&&e>a){this.pswp.close();return}}const p=n.correctPan(t,l);if(o===p)return;const d=p===l?1:.82;const c=this.pswp.bgOpacity;const u=p-o;this.pswp.animations.startSpring({name:"panGesture"+t,isPan:true,start:o,end:p,velocity:e[t],dampingRatio:d,onUpdate:e=>{if(r&&this.pswp.bgOpacity<1){const t=1-(p-e)/u;this.pswp.applyBgOpacity(clamp(c+(1-c)*t,0,1))}s[t]=Math.floor(e);i.applyCurrentZoomPan()}})}
/**
   * Update position of the main scroll,
   * or/and update pan position of the current slide.
   *
   * Should return true if it changes (or can change) main scroll.
   *
   * @private
   * @param {'x' | 'y'} axis
   * @returns {boolean}
   */_panOrMoveMainScroll(t){const{p1:e,dragAxis:i,prevP1:s,isMultitouch:n}=this.gestures;const{currSlide:o,mainScroll:a}=this.pswp;const r=e[t]-s[t];const h=a.x+r;if(!r||!o)return false;if(t==="x"&&!o.isPannable()&&!n){a.moveTo(h,true);return true}const{bounds:l}=o;const p=o.pan[t]+r;if(this.pswp.options.allowPanToNext&&i==="x"&&t==="x"&&!n){const e=a.getCurrSlideX();const i=a.x-e;const s=r>0;const n=!s;if(p>l.min[t]&&s){const e=l.min[t]<=this.startPan[t];if(e){a.moveTo(h,true);return true}this._setPanWithFriction(t,p)}else if(p<l.max[t]&&n){const e=this.startPan[t]<=l.max[t];if(e){a.moveTo(h,true);return true}this._setPanWithFriction(t,p)}else if(i!==0){if(i>0){a.moveTo(Math.max(h,e),true);return true}if(i<0){a.moveTo(Math.min(h,e),true);return true}}else this._setPanWithFriction(t,p)}else t==="y"&&(a.isShifted()||l.min.y===l.max.y)||this._setPanWithFriction(t,p);return false}
/**
   * Relation between pan Y position and third of viewport height.
   *
   * When we are at initial position (center bounds) - the ratio is 0,
   * if position is shifted upwards - the ratio is negative,
   * if position is shifted downwards - the ratio is positive.
   *
   * @private
   * @param {number} panY The current pan Y position.
   * @returns {number}
   */
_getVerticalDragRatio(t){var e,i;return(t-((e=(i=this.pswp.currSlide)===null||i===void 0?void 0:i.bounds.center.y)!==null&&e!==void 0?e:0))/(this.pswp.viewportSize.y/3)}
/**
   * Set pan position of the current slide.
   * Apply friction if the position is beyond the pan bounds,
   * or if custom friction is defined.
   *
   * @private
   * @param {'x' | 'y'} axis
   * @param {number} potentialPan
   * @param {number} [customFriction] (0.1 - 1)
   */_setPanWithFriction(t,e,i){const{currSlide:s}=this.pswp;if(!s)return;const{pan:o,bounds:a}=s;const r=a.correctPan(t,e);if(r!==e||i){const s=Math.round(e-o[t]);o[t]+=s*(i||n)}else o[t]=e}}
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {import('./gestures.js').default} Gestures */const h=.05;const l=.15;
/**
 * Get center point between two points
 *
 * @param {Point} p
 * @param {Point} p1
 * @param {Point} p2
 * @returns {Point}
 */function getZoomPointsCenter(t,e,i){t.x=(e.x+i.x)/2;t.y=(e.y+i.y)/2;return t}class ZoomHandler{
/**
   * @param {Gestures} gestures
   */
constructor(t){this.gestures=t;
/**
     * @private
     * @type {Point}
     */this._startPan={x:0,y:0};
/**
     * @private
     * @type {Point}
     */this._startZoomPoint={x:0,y:0};
/**
     * @private
     * @type {Point}
     */this._zoomPoint={x:0,y:0};this._wasOverFitZoomLevel=false;this._startZoomLevel=1}start(){const{currSlide:t}=this.gestures.pswp;if(t){this._startZoomLevel=t.currZoomLevel;equalizePoints(this._startPan,t.pan)}this.gestures.pswp.animations.stopAllPan();this._wasOverFitZoomLevel=false}change(){const{p1:t,startP1:e,p2:i,startP2:s,pswp:n}=this.gestures;const{currSlide:o}=n;if(!o)return;const a=o.zoomLevels.min;const r=o.zoomLevels.max;if(!o.isZoomable()||n.mainScroll.isShifted())return;getZoomPointsCenter(this._startZoomPoint,e,s);getZoomPointsCenter(this._zoomPoint,t,i);let p=1/getDistanceBetween(e,s)*getDistanceBetween(t,i)*this._startZoomLevel;p>o.zoomLevels.initial+o.zoomLevels.initial/15&&(this._wasOverFitZoomLevel=true);if(p<a)if(n.options.pinchToClose&&!this._wasOverFitZoomLevel&&this._startZoomLevel<=o.zoomLevels.initial){const t=1-(a-p)/(a/1.2);n.dispatch("pinchClose",{bgOpacity:t}).defaultPrevented||n.applyBgOpacity(t)}else p=a-(a-p)*l;else p>r&&(p=r+(p-r)*h);o.pan.x=this._calculatePanForZoomLevel("x",p);o.pan.y=this._calculatePanForZoomLevel("y",p);o.setZoomLevel(p);o.applyCurrentZoomPan()}end(){const{pswp:t}=this.gestures;const{currSlide:e}=t;(!e||e.currZoomLevel<e.zoomLevels.initial)&&!this._wasOverFitZoomLevel&&t.options.pinchToClose?t.close():this.correctZoomPan()}
/**
   * @private
   * @param {'x' | 'y'} axis
   * @param {number} currZoomLevel
   * @returns {number}
   */_calculatePanForZoomLevel(t,e){const i=e/this._startZoomLevel;return this._zoomPoint[t]-(this._startZoomPoint[t]-this._startPan[t])*i}
/**
   * Correct currZoomLevel and pan if they are
   * beyond minimum or maximum values.
   * With animation.
   *
   * @param {boolean} [ignoreGesture]
   * Wether gesture coordinates should be ignored when calculating destination pan position.
   */correctZoomPan(t){const{pswp:e}=this.gestures;const{currSlide:i}=e;if(!(i!==null&&i!==void 0&&i.isZoomable()))return;this._zoomPoint.x===0&&(t=true);const s=i.currZoomLevel;
/** @type {number} */let n;let o=true;if(s<i.zoomLevels.initial)n=i.zoomLevels.initial;else if(s>i.zoomLevels.max)n=i.zoomLevels.max;else{o=false;n=s}const a=e.bgOpacity;const r=e.bgOpacity<1;const h=equalizePoints({x:0,y:0},i.pan);let l=equalizePoints({x:0,y:0},h);if(t){this._zoomPoint.x=0;this._zoomPoint.y=0;this._startZoomPoint.x=0;this._startZoomPoint.y=0;this._startZoomLevel=s;equalizePoints(this._startPan,h)}o&&(l={x:this._calculatePanForZoomLevel("x",n),y:this._calculatePanForZoomLevel("y",n)});i.setZoomLevel(n);l={x:i.bounds.correctPan("x",l.x),y:i.bounds.correctPan("y",l.y)};i.setZoomLevel(s);const p=!pointsEqual(l,h);if(p||o||r){e.animations.stopAllPan();e.animations.startSpring({isPan:true,start:0,end:1e3,velocity:0,dampingRatio:1,naturalFrequency:40,onUpdate:t=>{t/=1e3;if(p||o){if(p){i.pan.x=h.x+(l.x-h.x)*t;i.pan.y=h.y+(l.y-h.y)*t}if(o){const e=s+(n-s)*t;i.setZoomLevel(e)}i.applyCurrentZoomPan()}r&&e.bgOpacity<1&&e.applyBgOpacity(clamp(a+(1-a)*t,0,1))},onComplete:()=>{i._setResolution(n);i.applyCurrentZoomPan()}})}else{i._setResolution(n);i.applyCurrentZoomPan()}}}
/**
 * @template {string} T
 * @template {string} P
 * @typedef {import('../types.js').AddPostfix<T, P>} AddPostfix<T, P>
 */
/** @typedef {import('./gestures.js').default} Gestures */
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {'imageClick' | 'bgClick' | 'tap' | 'doubleTap'} Actions */
/**
 * Whether the tap was performed on the main slide
 * (rather than controls or caption).
 *
 * @param {PointerEvent} event
 * @returns {boolean}
 */function didTapOnMainContent(t){return!!
/** @type {HTMLElement} */
t.target.closest(".pswp__container")}class TapHandler{
/**
   * @param {Gestures} gestures
   */
constructor(t){this.gestures=t}
/**
   * @param {Point} point
   * @param {PointerEvent} originalEvent
   */click(t,e){const i=
/** @type {HTMLElement} */
e.target.classList;const s=i.contains("pswp__img");const n=i.contains("pswp__item")||i.contains("pswp__zoom-wrap");s?this._doClickOrTapAction("imageClick",t,e):n&&this._doClickOrTapAction("bgClick",t,e)}
/**
   * @param {Point} point
   * @param {PointerEvent} originalEvent
   */tap(t,e){didTapOnMainContent(e)&&this._doClickOrTapAction("tap",t,e)}
/**
   * @param {Point} point
   * @param {PointerEvent} originalEvent
   */doubleTap(t,e){didTapOnMainContent(e)&&this._doClickOrTapAction("doubleTap",t,e)}
/**
   * @private
   * @param {Actions} actionName
   * @param {Point} point
   * @param {PointerEvent} originalEvent
   */_doClickOrTapAction(t,e,i){var s;const{pswp:n}=this.gestures;const{currSlide:o}=n;const a=
/** @type {AddPostfix<Actions, 'Action'>} */
t+"Action";const r=n.options[a];if(!n.dispatch(a,{point:e,originalEvent:i}).defaultPrevented)if(typeof r!=="function")switch(r){case"close":case"next":n[r]();break;case"zoom":o===null||o===void 0||o.toggleZoom(e);break;case"zoom-or-close":o!==null&&o!==void 0&&o.isZoomable()&&o.zoomLevels.secondary!==o.zoomLevels.initial?o.toggleZoom(e):n.options.clickToCloseNonZoomable&&n.close();break;case"toggle-controls":(s=this.gestures.pswp.element)===null||s===void 0||s.classList.toggle("pswp--ui-visible");break}else r.call(n,e,i)}}
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/** @typedef {import('../photoswipe.js').Point} Point */const p=10;const d=300;const c=25;class Gestures{
/**
   * @param {PhotoSwipe} pswp
   */
constructor(t){this.pswp=t;
/** @type {'x' | 'y' | null} */this.dragAxis=null;
/** @type {Point} */this.p1={x:0,y:0};
/** @type {Point} */this.p2={x:0,y:0};
/** @type {Point} */this.prevP1={x:0,y:0};
/** @type {Point} */this.prevP2={x:0,y:0};
/** @type {Point} */this.startP1={x:0,y:0};
/** @type {Point} */this.startP2={x:0,y:0};
/** @type {Point} */this.velocity={x:0,y:0};
/** @type {Point}
     * @private
     */this._lastStartP1={x:0,y:0};
/** @type {Point}
     * @private
     */this._intervalP1={x:0,y:0};this._numActivePoints=0;
/** @type {Point[]}
     * @private
     */this._ongoingPointers=[];this._touchEventEnabled="ontouchstart"in window;this._pointerEventEnabled=!!window.PointerEvent;this.supportsTouch=this._touchEventEnabled||this._pointerEventEnabled&&navigator.maxTouchPoints>1;this._numActivePoints=0;this._intervalTime=0;this._velocityCalculated=false;this.isMultitouch=false;this.isDragging=false;this.isZooming=false;
/** @type {number | null} */this.raf=null;
/** @type {NodeJS.Timeout | null}
     * @private
     */this._tapTimer=null;this.supportsTouch||(t.options.allowPanToNext=false);this.drag=new DragHandler(this);this.zoomLevels=new ZoomHandler(this);this.tapHandler=new TapHandler(this);t.on("bindEvents",(()=>{t.events.add(t.scrollWrap,"click",
/** @type EventListener */
this._onClick.bind(this));if(this._pointerEventEnabled)this._bindEvents("pointer","down","up","cancel");else if(this._touchEventEnabled){this._bindEvents("touch","start","end","cancel");if(t.scrollWrap){t.scrollWrap.ontouchmove=()=>{};t.scrollWrap.ontouchend=()=>{}}}else this._bindEvents("mouse","down","up")}))}
/**
   * @private
   * @param {'mouse' | 'touch' | 'pointer'} pref
   * @param {'down' | 'start'} down
   * @param {'up' | 'end'} up
   * @param {'cancel'} [cancel]
   */_bindEvents(t,e,i,s){const{pswp:n}=this;const{events:o}=n;const a=s?t+s:"";o.add(n.scrollWrap,t+e,
/** @type EventListener */
this.onPointerDown.bind(this));o.add(window,t+"move",
/** @type EventListener */
this.onPointerMove.bind(this));o.add(window,t+i,
/** @type EventListener */
this.onPointerUp.bind(this));a&&o.add(n.scrollWrap,a,
/** @type EventListener */
this.onPointerUp.bind(this))}
/**
   * @param {PointerEvent} e
   */onPointerDown(t){const e=t.type==="mousedown"||t.pointerType==="mouse";if(e&&t.button>0)return;const{pswp:i}=this;if(i.opener.isOpen){if(!i.dispatch("pointerDown",{originalEvent:t}).defaultPrevented){if(e){i.mouseDetected();this._preventPointerEventBehaviour(t,"down")}i.animations.stopAll();this._updatePoints(t,"down");if(this._numActivePoints===1){this.dragAxis=null;equalizePoints(this.startP1,this.p1)}if(this._numActivePoints>1){this._clearTapTimer();this.isMultitouch=true}else this.isMultitouch=false}}else t.preventDefault()}
/**
   * @param {PointerEvent} e
   */onPointerMove(t){this._preventPointerEventBehaviour(t,"move");if(this._numActivePoints){this._updatePoints(t,"move");if(!this.pswp.dispatch("pointerMove",{originalEvent:t}).defaultPrevented)if(this._numActivePoints!==1||this.isDragging){if(this._numActivePoints>1&&!this.isZooming){this._finishDrag();this.isZooming=true;this._updateStartPoints();this.zoomLevels.start();this._rafStopLoop();this._rafRenderLoop()}}else{this.dragAxis||this._calculateDragDirection();if(this.dragAxis&&!this.isDragging){if(this.isZooming){this.isZooming=false;this.zoomLevels.end()}this.isDragging=true;this._clearTapTimer();this._updateStartPoints();this._intervalTime=Date.now();this._velocityCalculated=false;equalizePoints(this._intervalP1,this.p1);this.velocity.x=0;this.velocity.y=0;this.drag.start();this._rafStopLoop();this._rafRenderLoop()}}}}_finishDrag(){if(this.isDragging){this.isDragging=false;this._velocityCalculated||this._updateVelocity(true);this.drag.end();this.dragAxis=null}}
/**
   * @param {PointerEvent} e
   */onPointerUp(t){if(this._numActivePoints){this._updatePoints(t,"up");if(!this.pswp.dispatch("pointerUp",{originalEvent:t}).defaultPrevented){if(this._numActivePoints===0){this._rafStopLoop();this.isDragging?this._finishDrag():this.isZooming||this.isMultitouch||this._finishTap(t)}if(this._numActivePoints<2&&this.isZooming){this.isZooming=false;this.zoomLevels.end();if(this._numActivePoints===1){this.dragAxis=null;this._updateStartPoints()}}}}}_rafRenderLoop(){if(this.isDragging||this.isZooming){this._updateVelocity();this.isDragging?pointsEqual(this.p1,this.prevP1)||this.drag.change():pointsEqual(this.p1,this.prevP1)&&pointsEqual(this.p2,this.prevP2)||this.zoomLevels.change();this._updatePrevPoints();this.raf=requestAnimationFrame(this._rafRenderLoop.bind(this))}}
/**
   * Update velocity at 50ms interval
   *
   * @private
   * @param {boolean} [force]
   */_updateVelocity(t){const e=Date.now();const i=e-this._intervalTime;if(!(i<50)||t){this.velocity.x=this._getVelocity("x",i);this.velocity.y=this._getVelocity("y",i);this._intervalTime=e;equalizePoints(this._intervalP1,this.p1);this._velocityCalculated=true}}
/**
   * @private
   * @param {PointerEvent} e
   */_finishTap(t){const{mainScroll:e}=this.pswp;if(e.isShifted()){e.moveIndexBy(0,true);return}if(t.type.indexOf("cancel")>0)return;if(t.type==="mouseup"||t.pointerType==="mouse"){this.tapHandler.click(this.startP1,t);return}const i=this.pswp.options.doubleTapAction?d:0;if(this._tapTimer){this._clearTapTimer();getDistanceBetween(this._lastStartP1,this.startP1)<c&&this.tapHandler.doubleTap(this.startP1,t)}else{equalizePoints(this._lastStartP1,this.startP1);this._tapTimer=setTimeout((()=>{this.tapHandler.tap(this.startP1,t);this._clearTapTimer()}),i)}}_clearTapTimer(){if(this._tapTimer){clearTimeout(this._tapTimer);this._tapTimer=null}}
/**
   * Get velocity for axis
   *
   * @private
   * @param {'x' | 'y'} axis
   * @param {number} duration
   * @returns {number}
   */_getVelocity(t,e){const i=this.p1[t]-this._intervalP1[t];return Math.abs(i)>1&&e>5?i/e:0}_rafStopLoop(){if(this.raf){cancelAnimationFrame(this.raf);this.raf=null}}
/**
   * @private
   * @param {PointerEvent} e
   * @param {'up' | 'down' | 'move'} pointerType Normalized pointer type
   */_preventPointerEventBehaviour(t,e){const i=this.pswp.applyFilters("preventPointerEvent",true,t,e);i&&t.preventDefault()}
/**
   * Parses and normalizes points from the touch, mouse or pointer event.
   * Updates p1 and p2.
   *
   * @private
   * @param {PointerEvent | TouchEvent} e
   * @param {'up' | 'down' | 'move'} pointerType Normalized pointer type
   */_updatePoints(t,e){if(this._pointerEventEnabled){const i=
/** @type {PointerEvent} */
t;const s=this._ongoingPointers.findIndex((t=>t.id===i.pointerId));e==="up"&&s>-1?this._ongoingPointers.splice(s,1):e==="down"&&s===-1?this._ongoingPointers.push(this._convertEventPosToPoint(i,{x:0,y:0})):s>-1&&this._convertEventPosToPoint(i,this._ongoingPointers[s]);this._numActivePoints=this._ongoingPointers.length;this._numActivePoints>0&&equalizePoints(this.p1,this._ongoingPointers[0]);this._numActivePoints>1&&equalizePoints(this.p2,this._ongoingPointers[1])}else{const i=
/** @type {TouchEvent} */
t;this._numActivePoints=0;if(i.type.indexOf("touch")>-1){if(i.touches&&i.touches.length>0){this._convertEventPosToPoint(i.touches[0],this.p1);this._numActivePoints++;if(i.touches.length>1){this._convertEventPosToPoint(i.touches[1],this.p2);this._numActivePoints++}}}else{this._convertEventPosToPoint(
/** @type {PointerEvent} */
t,this.p1);e==="up"?this._numActivePoints=0:this._numActivePoints++}}}_updatePrevPoints(){equalizePoints(this.prevP1,this.p1);equalizePoints(this.prevP2,this.p2)}_updateStartPoints(){equalizePoints(this.startP1,this.p1);equalizePoints(this.startP2,this.p2);this._updatePrevPoints()}_calculateDragDirection(){if(this.pswp.mainScroll.isShifted())this.dragAxis="x";else{const t=Math.abs(this.p1.x-this.startP1.x)-Math.abs(this.p1.y-this.startP1.y);if(t!==0){const e=t>0?"x":"y";Math.abs(this.p1[e]-this.startP1[e])>=p&&(this.dragAxis=e)}}}
/**
   * Converts touch, pointer or mouse event
   * to PhotoSwipe point.
   *
   * @private
   * @param {Touch | PointerEvent} e
   * @param {Point} p
   * @returns {Point}
   */_convertEventPosToPoint(t,e){e.x=t.pageX-this.pswp.offset.x;e.y=t.pageY-this.pswp.offset.y;"pointerId"in t?e.id=t.pointerId:t.identifier!==void 0&&(e.id=t.identifier);return e}
/**
   * @private
   * @param {PointerEvent} e
   */_onClick(t){if(this.pswp.mainScroll.isShifted()){t.preventDefault();t.stopPropagation()}}}
/** @typedef {import('./photoswipe.js').default} PhotoSwipe */
/** @typedef {import('./slide/slide.js').default} Slide */
/** @typedef {{ el: HTMLDivElement; slide?: Slide }} ItemHolder */const u=.35;class MainScroll{
/**
   * @param {PhotoSwipe} pswp
   */
constructor(t){this.pswp=t;this.x=0;this.slideWidth=0;this._currPositionIndex=0;this._prevPositionIndex=0;this._containerShiftIndex=-1;
/** @type {ItemHolder[]} */this.itemHolders=[]}
/**
   * Position the scroller and slide containers
   * according to viewport size.
   *
   * @param {boolean} [resizeSlides] Whether slides content should resized
   */resize(t){const{pswp:e}=this;const i=Math.round(e.viewportSize.x+e.viewportSize.x*e.options.spacing);const s=i!==this.slideWidth;if(s){this.slideWidth=i;this.moveTo(this.getCurrSlideX())}this.itemHolders.forEach(((e,i)=>{s&&setTransform(e.el,(i+this._containerShiftIndex)*this.slideWidth);t&&e.slide&&e.slide.resize()}))}resetPosition(){this._currPositionIndex=0;this._prevPositionIndex=0;this.slideWidth=0;this._containerShiftIndex=-1}appendHolders(){this.itemHolders=[];for(let t=0;t<3;t++){const e=createElement("pswp__item","div",this.pswp.container);e.setAttribute("role","group");e.setAttribute("aria-roledescription","slide");e.setAttribute("aria-hidden","true");e.style.display=t===1?"block":"none";this.itemHolders.push({el:e})}}
/**
   * Whether the main scroll can be horizontally swiped to the next or previous slide.
   * @returns {boolean}
   */canBeSwiped(){return this.pswp.getNumItems()>1}
/**
   * Move main scroll by X amount of slides.
   * For example:
   *   `-1` will move to the previous slide,
   *    `0` will reset the scroll position of the current slide,
   *    `3` will move three slides forward
   *
   * If loop option is enabled - index will be automatically looped too,
   * (for example `-1` will move to the last slide of the gallery).
   *
   * @param {number} diff
   * @param {boolean} [animate]
   * @param {number} [velocityX]
   * @returns {boolean} whether index was changed or not
   */moveIndexBy(t,e,i){const{pswp:s}=this;let n=s.potentialIndex+t;const o=s.getNumItems();if(s.canLoop()){n=s.getLoopedIndex(n);const e=(t+o)%o;t=e<=o/2?e:e-o}else{n<0?n=0:n>=o&&(n=o-1);t=n-s.potentialIndex}s.potentialIndex=n;this._currPositionIndex-=t;s.animations.stopMainScroll();const a=this.getCurrSlideX();if(e){s.animations.startSpring({isMainScroll:true,start:this.x,end:a,velocity:i||0,naturalFrequency:30,dampingRatio:1,onUpdate:t=>{this.moveTo(t)},onComplete:()=>{this.updateCurrItem();s.appendHeavy()}});let t=s.potentialIndex-s.currIndex;if(s.canLoop()){const e=(t+o)%o;t=e<=o/2?e:e-o}Math.abs(t)>1&&this.updateCurrItem()}else{this.moveTo(a);this.updateCurrItem()}return Boolean(t)}
/**
   * X position of the main scroll for the current slide
   * (ignores position during dragging)
   * @returns {number}
   */getCurrSlideX(){return this.slideWidth*this._currPositionIndex}
/**
   * Whether scroll position is shifted.
   * For example, it will return true if the scroll is being dragged or animated.
   * @returns {boolean}
   */isShifted(){return this.x!==this.getCurrSlideX()}updateCurrItem(){var t;const{pswp:e}=this;const i=this._prevPositionIndex-this._currPositionIndex;if(!i)return;this._prevPositionIndex=this._currPositionIndex;e.currIndex=e.potentialIndex;let s=Math.abs(i);
/** @type {ItemHolder | undefined} */let n;if(s>=3){this._containerShiftIndex+=i+(i>0?-3:3);s=3;this.itemHolders.forEach((t=>{var e;(e=t.slide)===null||e===void 0||e.destroy();t.slide=void 0}))}for(let t=0;t<s;t++)if(i>0){n=this.itemHolders.shift();if(n){this.itemHolders[2]=n;this._containerShiftIndex++;setTransform(n.el,(this._containerShiftIndex+2)*this.slideWidth);e.setContent(n,e.currIndex-s+t+2)}}else{n=this.itemHolders.pop();if(n){this.itemHolders.unshift(n);this._containerShiftIndex--;setTransform(n.el,this._containerShiftIndex*this.slideWidth);e.setContent(n,e.currIndex+s-t-2)}}if(Math.abs(this._containerShiftIndex)>50&&!this.isShifted()){this.resetPosition();this.resize()}e.animations.stopAllPan();this.itemHolders.forEach(((t,e)=>{t.slide&&t.slide.setIsActive(e===1)}));e.currSlide=(t=this.itemHolders[1])===null||t===void 0?void 0:t.slide;e.contentLoader.updateLazy(i);e.currSlide&&e.currSlide.applyCurrentZoomPan();e.dispatch("change")}
/**
   * Move the X position of the main scroll container
   *
   * @param {number} x
   * @param {boolean} [dragging]
   */moveTo(t,e){if(!this.pswp.canLoop()&&e){let e=(this.slideWidth*this._currPositionIndex-t)/this.slideWidth;e+=this.pswp.currIndex;const i=Math.round(t-this.x);(e<0&&i>0||e>=this.pswp.getNumItems()-1&&i<0)&&(t=this.x+i*u)}this.x=t;this.pswp.container&&setTransform(this.pswp.container,t);this.pswp.dispatch("moveMainScroll",{x:t,dragging:e!==null&&e!==void 0&&e})}}
/** @typedef {import('./photoswipe.js').default} PhotoSwipe */
/**
 * @template T
 * @typedef {import('./types.js').Methods<T>} Methods<T>
 */const m={Escape:27,z:90,ArrowLeft:37,ArrowUp:38,ArrowRight:39,ArrowDown:40,Tab:9};
/**
 * @template {keyof KeyboardKeyCodesMap} T
 * @param {T} key
 * @param {boolean} isKeySupported
 * @returns {T | number | undefined}
 */const getKeyboardEventKey=(t,e)=>e?t:m[t];class Keyboard{
/**
   * @param {PhotoSwipe} pswp
   */
constructor(t){this.pswp=t;this._wasFocused=false;t.on("bindEvents",(()=>{if(t.options.trapFocus){t.options.initialPointerPos||this._focusRoot();t.events.add(document,"focusin",
/** @type EventListener */
this._onFocusIn.bind(this))}t.events.add(document,"keydown",
/** @type EventListener */
this._onKeyDown.bind(this))}));const e=
/** @type {HTMLElement} */
document.activeElement;t.on("destroy",(()=>{t.options.returnFocus&&e&&this._wasFocused&&e.focus()}))}_focusRoot(){if(!this._wasFocused&&this.pswp.element){this.pswp.element.focus();this._wasFocused=true}}
/**
   * @private
   * @param {KeyboardEvent} e
   */_onKeyDown(t){const{pswp:e}=this;if(e.dispatch("keydown",{originalEvent:t}).defaultPrevented)return;if(specialKeyUsed(t))return;
/** @type {Methods<PhotoSwipe> | undefined} */let i;
/** @type {'x' | 'y' | undefined} */let s;let n=false;const o="key"in t;switch(o?t.key:t.keyCode){case getKeyboardEventKey("Escape",o):e.options.escKey&&(i="close");break;case getKeyboardEventKey("z",o):i="toggleZoom";break;case getKeyboardEventKey("ArrowLeft",o):s="x";break;case getKeyboardEventKey("ArrowUp",o):s="y";break;case getKeyboardEventKey("ArrowRight",o):s="x";n=true;break;case getKeyboardEventKey("ArrowDown",o):n=true;s="y";break;case getKeyboardEventKey("Tab",o):this._focusRoot();break}if(s){t.preventDefault();const{currSlide:o}=e;if(e.options.arrowKeys&&s==="x"&&e.getNumItems()>1)i=n?"next":"prev";else if(o&&o.currZoomLevel>o.zoomLevels.fit){o.pan[s]+=n?-80:80;o.panTo(o.pan.x,o.pan.y)}}if(i){t.preventDefault();e[i]()}}
/**
   * Trap focus inside photoswipe
   *
   * @private
   * @param {FocusEvent} e
   */_onFocusIn(t){const{template:e}=this.pswp;e&&document!==t.target&&e!==t.target&&!e.contains(
/** @type {Node} */
t.target)&&e.focus()}}const f="cubic-bezier(.4,0,.22,1)";
/** @typedef {import('./animations.js').SharedAnimationProps} SharedAnimationProps */
/** @typedef {Object} DefaultCssAnimationProps
 *
 * @prop {HTMLElement} target
 * @prop {number} [duration]
 * @prop {string} [easing]
 * @prop {string} [transform]
 * @prop {string} [opacity]
 * */
/** @typedef {SharedAnimationProps & DefaultCssAnimationProps} CssAnimationProps */class CSSAnimation{
/**
   * onComplete can be unpredictable, be careful about current state
   *
   * @param {CssAnimationProps} props
   */
constructor(t){var e;this.props=t;const{target:i,onComplete:s,transform:n,onFinish:o=(()=>{}),duration:a=333,easing:r=f}=t;this.onFinish=o;const h=n?"transform":"opacity";const l=(e=t[h])!==null&&e!==void 0?e:"";this._target=i;this._onComplete=s;this._finished=false;this._onTransitionEnd=this._onTransitionEnd.bind(this);this._helperTimeout=setTimeout((()=>{setTransitionStyle(i,h,a,r);this._helperTimeout=setTimeout((()=>{i.addEventListener("transitionend",this._onTransitionEnd,false);i.addEventListener("transitioncancel",this._onTransitionEnd,false);this._helperTimeout=setTimeout((()=>{this._finalizeAnimation()}),a+500);i.style[h]=l}),30)}),0)}
/**
   * @private
   * @param {TransitionEvent} e
   */_onTransitionEnd(t){t.target===this._target&&this._finalizeAnimation()}_finalizeAnimation(){if(!this._finished){this._finished=true;this.onFinish();this._onComplete&&this._onComplete()}}destroy(){this._helperTimeout&&clearTimeout(this._helperTimeout);removeTransitionStyle(this._target);this._target.removeEventListener("transitionend",this._onTransitionEnd,false);this._target.removeEventListener("transitioncancel",this._onTransitionEnd,false);this._finished||this._finalizeAnimation()}}const v=12;const g=.75;class SpringEaser{
/**
   * @param {number} initialVelocity Initial velocity, px per ms.
   *
   * @param {number} [dampingRatio]
   * Determines how bouncy animation will be.
   * From 0 to 1, 0 - always overshoot, 1 - do not overshoot.
   * "overshoot" refers to part of animation that
   * goes beyond the final value.
   *
   * @param {number} [naturalFrequency]
   * Determines how fast animation will slow down.
   * The higher value - the stiffer the transition will be,
   * and the faster it will slow down.
   * Recommended value from 10 to 50
   */
constructor(t,e,i){this.velocity=t*1e3;this._dampingRatio=e||g;this._naturalFrequency=i||v;this._dampedFrequency=this._naturalFrequency;this._dampingRatio<1&&(this._dampedFrequency*=Math.sqrt(1-this._dampingRatio*this._dampingRatio))}
/**
   * @param {number} deltaPosition Difference between current and end position of the animation
   * @param {number} deltaTime Frame duration in milliseconds
   *
   * @returns {number} Displacement, relative to the end position.
   */easeFrame(t,e){let i=0;let s;e/=1e3;const n=Math.E**(-this._dampingRatio*this._naturalFrequency*e);if(this._dampingRatio===1){s=this.velocity+this._naturalFrequency*t;i=(t+s*e)*n;this.velocity=i*-this._naturalFrequency+s*n}else if(this._dampingRatio<1){s=1/this._dampedFrequency*(this._dampingRatio*this._naturalFrequency*t+this.velocity);const o=Math.cos(this._dampedFrequency*e);const a=Math.sin(this._dampedFrequency*e);i=n*(t*o+s*a);this.velocity=i*-this._naturalFrequency*this._dampingRatio+n*(-this._dampedFrequency*t*a+this._dampedFrequency*s*o)}return i}}
/** @typedef {import('./animations.js').SharedAnimationProps} SharedAnimationProps */
/**
 * @typedef {Object} DefaultSpringAnimationProps
 *
 * @prop {number} start
 * @prop {number} end
 * @prop {number} velocity
 * @prop {number} [dampingRatio]
 * @prop {number} [naturalFrequency]
 * @prop {(end: number) => void} onUpdate
 */
/** @typedef {SharedAnimationProps & DefaultSpringAnimationProps} SpringAnimationProps */class SpringAnimation{
/**
   * @param {SpringAnimationProps} props
   */
constructor(t){this.props=t;this._raf=0;const{start:e,end:i,velocity:s,onUpdate:n,onComplete:o,onFinish:a=(()=>{}),dampingRatio:r,naturalFrequency:h}=t;this.onFinish=a;const l=new SpringEaser(s,r,h);let p=Date.now();let d=e-i;const animationLoop=()=>{if(this._raf){d=l.easeFrame(d,Date.now()-p);if(Math.abs(d)<1&&Math.abs(l.velocity)<50){n(i);o&&o();this.onFinish()}else{p=Date.now();n(d+i);this._raf=requestAnimationFrame(animationLoop)}}};this._raf=requestAnimationFrame(animationLoop)}destroy(){this._raf>=0&&cancelAnimationFrame(this._raf);this._raf=0}}
/** @typedef {import('./css-animation.js').CssAnimationProps} CssAnimationProps */
/** @typedef {import('./spring-animation.js').SpringAnimationProps} SpringAnimationProps */
/** @typedef {Object} SharedAnimationProps
 * @prop {string} [name]
 * @prop {boolean} [isPan]
 * @prop {boolean} [isMainScroll]
 * @prop {VoidFunction} [onComplete]
 * @prop {VoidFunction} [onFinish]
 */
/** @typedef {SpringAnimation | CSSAnimation} Animation */
/** @typedef {SpringAnimationProps | CssAnimationProps} AnimationProps */class Animations{constructor(){
/** @type {Animation[]} */
this.activeAnimations=[]}
/**
   * @param {SpringAnimationProps} props
   */startSpring(t){this._start(t,true)}
/**
   * @param {CssAnimationProps} props
   */startTransition(t){this._start(t)}
/**
   * @private
   * @param {AnimationProps} props
   * @param {boolean} [isSpring]
   * @returns {Animation}
   */_start(t,e){const i=e?new SpringAnimation(
/** @type SpringAnimationProps */
t):new CSSAnimation(
/** @type CssAnimationProps */
t);this.activeAnimations.push(i);i.onFinish=()=>this.stop(i);return i}
/**
   * @param {Animation} animation
   */stop(t){t.destroy();const e=this.activeAnimations.indexOf(t);e>-1&&this.activeAnimations.splice(e,1)}stopAll(){this.activeAnimations.forEach((t=>{t.destroy()}));this.activeAnimations=[]}stopAllPan(){this.activeAnimations=this.activeAnimations.filter((t=>{if(t.props.isPan){t.destroy();return false}return true}))}stopMainScroll(){this.activeAnimations=this.activeAnimations.filter((t=>{if(t.props.isMainScroll){t.destroy();return false}return true}))}isPanRunning(){return this.activeAnimations.some((t=>t.props.isPan))}}
/** @typedef {import('./photoswipe.js').default} PhotoSwipe */class ScrollWheel{
/**
   * @param {PhotoSwipe} pswp
   */
constructor(t){this.pswp=t;t.events.add(t.element,"wheel",
/** @type EventListener */
this._onWheel.bind(this))}
/**
   * @private
   * @param {WheelEvent} e
   */_onWheel(t){t.preventDefault();const{currSlide:e}=this.pswp;let{deltaX:i,deltaY:s}=t;if(e&&!this.pswp.dispatch("wheel",{originalEvent:t}).defaultPrevented)if(t.ctrlKey||this.pswp.options.wheelToZoom){if(e.isZoomable()){let i=-s;t.deltaMode===1?i*=.05:i*=t.deltaMode?1:.002;i=2**i;const n=e.currZoomLevel*i;e.zoomTo(n,{x:t.clientX,y:t.clientY})}}else if(e.isPannable()){if(t.deltaMode===1){i*=18;s*=18}e.panTo(e.pan.x-i,e.pan.y-s)}}}
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/**
 * @template T
 * @typedef {import('../types.js').Methods<T>} Methods<T>
 */
/**
 * @typedef {Object} UIElementMarkupProps
 * @prop {boolean} [isCustomSVG]
 * @prop {string} inner
 * @prop {string} [outlineID]
 * @prop {number | string} [size]
 */
/**
 * @typedef {Object} UIElementData
 * @prop {DefaultUIElements | string} [name]
 * @prop {string} [className]
 * @prop {UIElementMarkup} [html]
 * @prop {boolean} [isButton]
 * @prop {keyof HTMLElementTagNameMap} [tagName]
 * @prop {string} [title]
 * @prop {string} [ariaLabel]
 * @prop {(element: HTMLElement, pswp: PhotoSwipe) => void} [onInit]
 * @prop {Methods<PhotoSwipe> | ((e: MouseEvent, element: HTMLElement, pswp: PhotoSwipe) => void)} [onClick]
 * @prop {'bar' | 'wrapper' | 'root'} [appendTo]
 * @prop {number} [order]
 */
/** @typedef {'arrowPrev' | 'arrowNext' | 'close' | 'zoom' | 'counter'} DefaultUIElements */
/** @typedef {string | UIElementMarkupProps} UIElementMarkup */
/**
 * @param {UIElementMarkup} [htmlData]
 * @returns {string}
 */function addElementHTML(t){if(typeof t==="string")return t;if(!t||!t.isCustomSVG)return"";const e=t;let i='<svg aria-hidden="true" class="pswp__icn" viewBox="0 0 %d %d" width="%d" height="%d">';i=i.split("%d").join(
/** @type {string} */
e.size||32);e.outlineID&&(i+='<use class="pswp__icn-shadow" xlink:href="#'+e.outlineID+'"/>');i+=e.inner;i+="</svg>";return i}class UIElement{
/**
   * @param {PhotoSwipe} pswp
   * @param {UIElementData} data
   */
constructor(t,e){var i;const s=e.name||e.className;let n=e.html;if(t.options[s]===false)return;typeof t.options[s+"SVG"]==="string"&&(n=t.options[s+"SVG"]);t.dispatch("uiElementCreate",{data:e});let o="";if(e.isButton){o+="pswp__button ";o+=e.className||`pswp__button--${e.name}`}else o+=e.className||`pswp__${e.name}`;let a=e.isButton?e.tagName||"button":e.tagName||"div";a=
/** @type {keyof HTMLElementTagNameMap} */
a.toLowerCase();
/** @type {HTMLElement} */const r=createElement(o,a);if(e.isButton){a==="button"&&(
/** @type {HTMLButtonElement} */
r.type="button");let{title:i}=e;const{ariaLabel:n}=e;typeof t.options[s+"Title"]==="string"&&(i=t.options[s+"Title"]);i&&(r.title=i);const o=n||i;o&&r.setAttribute("aria-label",o)}r.innerHTML=addElementHTML(n);e.onInit&&e.onInit(r,t);e.onClick&&(r.onclick=i=>{typeof e.onClick==="string"?t[e.onClick]():typeof e.onClick==="function"&&e.onClick(i,r,t)});const h=e.appendTo||"bar";
/** @type {HTMLElement | undefined} root element by default */let l=t.element;if(h==="bar"){t.topBar||(t.topBar=createElement("pswp__top-bar pswp__hide-on-close","div",t.scrollWrap));l=t.topBar}else{r.classList.add("pswp__hide-on-close");h==="wrapper"&&(l=t.scrollWrap)}(i=l)===null||i===void 0||i.appendChild(t.applyFilters("uiElement",r,e))}}
/** @typedef {import('./ui-element.js').UIElementData} UIElementData */
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/**
 *
 * @param {HTMLElement} element
 * @param {PhotoSwipe} pswp
 * @param {boolean} [isNextButton]
 */function initArrowButton(t,e,i){t.classList.add("pswp__button--arrow");t.setAttribute("aria-controls","pswp__items");e.on("change",(()=>{e.options.loop||(
/** @type {HTMLButtonElement} */
t.disabled=i?!(e.currIndex<e.getNumItems()-1):!(e.currIndex>0))}))}
/** @type {UIElementData} */const _={name:"arrowPrev",className:"pswp__button--arrow--prev",title:"Previous",order:10,isButton:true,appendTo:"wrapper",html:{isCustomSVG:true,size:60,inner:'<path d="M29 43l-3 3-16-16 16-16 3 3-13 13 13 13z" id="pswp__icn-arrow"/>',outlineID:"pswp__icn-arrow"},onClick:"prev",onInit:initArrowButton};
/** @type {UIElementData} */const y={name:"arrowNext",className:"pswp__button--arrow--next",title:"Next",order:11,isButton:true,appendTo:"wrapper",html:{isCustomSVG:true,size:60,inner:'<use xlink:href="#pswp__icn-arrow"/>',outlineID:"pswp__icn-arrow"},onClick:"next",onInit:(t,e)=>{initArrowButton(t,e,true)}};
/** @type {import('./ui-element.js').UIElementData} UIElementData */const w={name:"close",title:"Close",order:20,isButton:true,html:{isCustomSVG:true,inner:'<path d="M24 10l-2-2-6 6-6-6-2 2 6 6-6 6 2 2 6-6 6 6 2-2-6-6z" id="pswp__icn-close"/>',outlineID:"pswp__icn-close"},onClick:"close"};
/** @type {import('./ui-element.js').UIElementData} UIElementData */const P={name:"zoom",title:"Zoom",order:10,isButton:true,html:{isCustomSVG:true,inner:'<path d="M17.426 19.926a6 6 0 1 1 1.5-1.5L23 22.5 21.5 24l-4.074-4.074z" id="pswp__icn-zoom"/><path fill="currentColor" class="pswp__zoom-icn-bar-h" d="M11 16v-2h6v2z"/><path fill="currentColor" class="pswp__zoom-icn-bar-v" d="M13 12h2v6h-2z"/>',outlineID:"pswp__icn-zoom"},onClick:"toggleZoom"};
/** @type {import('./ui-element.js').UIElementData} UIElementData */const S={name:"preloader",appendTo:"bar",order:7,html:{isCustomSVG:true,inner:'<path fill-rule="evenodd" clip-rule="evenodd" d="M21.2 16a5.2 5.2 0 1 1-5.2-5.2V8a8 8 0 1 0 8 8h-2.8Z" id="pswp__icn-loading"/>',outlineID:"pswp__icn-loading"},onInit:(t,e)=>{
/** @type {boolean | undefined} */
let i;
/** @type {NodeJS.Timeout | null} */let s=null;
/**
     * @param {string} className
     * @param {boolean} add
     */const toggleIndicatorClass=(e,i)=>{t.classList.toggle("pswp__preloader--"+e,i)};
/**
     * @param {boolean} visible
     */const setIndicatorVisibility=t=>{if(i!==t){i=t;toggleIndicatorClass("active",t)}};const updatePreloaderVisibility=()=>{var t;if((t=e.currSlide)!==null&&t!==void 0&&t.content.isLoading())s||(s=setTimeout((()=>{var t;setIndicatorVisibility(Boolean((t=e.currSlide)===null||t===void 0?void 0:t.content.isLoading()));s=null}),e.options.preloaderDelay));else{setIndicatorVisibility(false);if(s){clearTimeout(s);s=null}}};e.on("change",updatePreloaderVisibility);e.on("loadComplete",(t=>{e.currSlide===t.slide&&updatePreloaderVisibility()}));e.ui&&(e.ui.updatePreloaderVisibility=updatePreloaderVisibility)}};
/** @type {import('./ui-element.js').UIElementData} UIElementData */const x={name:"counter",order:5,onInit:(t,e)=>{e.on("change",(()=>{t.innerText=e.currIndex+1+e.options.indexIndicatorSep+e.getNumItems()}))}};
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/** @typedef {import('./ui-element.js').UIElementData} UIElementData */
/**
 * Set special class on element when image is zoomed.
 *
 * By default, it is used to adjust
 * zoom icon and zoom cursor via CSS.
 *
 * @param {HTMLElement} el
 * @param {boolean} isZoomedIn
 */function setZoomedIn(t,e){t.classList.toggle("pswp--zoomed-in",e)}class UI{
/**
   * @param {PhotoSwipe} pswp
   */
constructor(t){this.pswp=t;this.isRegistered=false;
/** @type {UIElementData[]} */this.uiElementsData=[];
/** @type {(UIElement | UIElementData)[]} */this.items=[];
/** @type {() => void} */this.updatePreloaderVisibility=()=>{};
/**
     * @private
     * @type {number | undefined}
     */this._lastUpdatedZoomLevel=void 0}init(){const{pswp:t}=this;this.isRegistered=false;this.uiElementsData=[w,_,y,P,S,x];t.dispatch("uiRegister");this.uiElementsData.sort(((t,e)=>(t.order||0)-(e.order||0)));this.items=[];this.isRegistered=true;this.uiElementsData.forEach((t=>{this.registerElement(t)}));t.on("change",(()=>{var e;(e=t.element)===null||e===void 0||e.classList.toggle("pswp--one-slide",t.getNumItems()===1)}));t.on("zoomPanUpdate",(()=>this._onZoomPanUpdate()))}
/**
   * @param {UIElementData} elementData
   */registerElement(t){this.isRegistered?this.items.push(new UIElement(this.pswp,t)):this.uiElementsData.push(t)}_onZoomPanUpdate(){const{template:t,currSlide:e,options:i}=this.pswp;if(this.pswp.opener.isClosing||!t||!e)return;let{currZoomLevel:s}=e;this.pswp.opener.isOpen||(s=e.zoomLevels.initial);if(s===this._lastUpdatedZoomLevel)return;this._lastUpdatedZoomLevel=s;const n=e.zoomLevels.initial-e.zoomLevels.secondary;if(Math.abs(n)<.01||!e.isZoomable()){setZoomedIn(t,false);t.classList.remove("pswp--zoom-allowed");return}t.classList.add("pswp--zoom-allowed");const o=s===e.zoomLevels.initial?e.zoomLevels.secondary:e.zoomLevels.initial;setZoomedIn(t,o<=s);i.imageClickAction!=="zoom"&&i.imageClickAction!=="zoom-or-close"||t.classList.add("pswp--click-to-zoom")}}
/** @typedef {import('./slide.js').SlideData} SlideData */
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/** @typedef {{ x: number; y: number; w: number; innerRect?: { w: number; h: number; x: number; y: number } }} Bounds */
/**
 * @param {HTMLElement} el
 * @returns Bounds
 */function getBoundsByElement(t){const e=t.getBoundingClientRect();return{x:e.left,y:e.top,w:e.width}}
/**
 * @param {HTMLElement} el
 * @param {number} imageWidth
 * @param {number} imageHeight
 * @returns Bounds
 */function getCroppedBoundsByElement(t,e,i){const s=t.getBoundingClientRect();const n=s.width/e;const o=s.height/i;const a=n>o?n:o;const r=(s.width-e*a)/2;const h=(s.height-i*a)/2;
/**
   * Coordinates of the image,
   * as if it was not cropped,
   * height is calculated automatically
   *
   * @type {Bounds}
   */const l={x:s.left+r,y:s.top+h,w:e*a};l.innerRect={w:s.width,h:s.height,x:r,y:h};return l}
/**
 * Get dimensions of thumbnail image
 * (click on which opens photoswipe or closes photoswipe to)
 *
 * @param {number} index
 * @param {SlideData} itemData
 * @param {PhotoSwipe} instance PhotoSwipe instance
 * @returns {Bounds | undefined}
 */function getThumbBounds(t,e,i){const s=i.dispatch("thumbBounds",{index:t,itemData:e,instance:i});if(s.thumbBounds)return s.thumbBounds;const{element:n}=e;
/** @type {Bounds | undefined} */let o;
/** @type {HTMLElement | null | undefined} */let a;if(n&&i.options.thumbSelector!==false){const t=i.options.thumbSelector||"img";a=n.matches(t)?n:
/** @type {HTMLElement | null} */
n.querySelector(t)}a=i.applyFilters("thumbEl",a,e,t);a&&(o=e.thumbCropped?getCroppedBoundsByElement(a,e.width||e.w||0,e.height||e.h||0):getBoundsByElement(a));return i.applyFilters("thumbBounds",o,e,t)}
/** @typedef {import('../lightbox/lightbox.js').default} PhotoSwipeLightbox */
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/** @typedef {import('../photoswipe.js').PhotoSwipeOptions} PhotoSwipeOptions */
/** @typedef {import('../photoswipe.js').DataSource} DataSource */
/** @typedef {import('../ui/ui-element.js').UIElementData} UIElementData */
/** @typedef {import('../slide/content.js').default} ContentDefault */
/** @typedef {import('../slide/slide.js').default} Slide */
/** @typedef {import('../slide/slide.js').SlideData} SlideData */
/** @typedef {import('../slide/zoom-level.js').default} ZoomLevel */
/** @typedef {import('../slide/get-thumb-bounds.js').Bounds} Bounds */
/**
 * Allow adding an arbitrary props to the Content
 * https://photoswipe.com/custom-content/#using-webp-image-format
 * @typedef {ContentDefault & Record<string, any>} Content
 */
/** @typedef {{ x?: number; y?: number }} Point */
/**
 * @typedef {Object} PhotoSwipeEventsMap https://photoswipe.com/events/
 *
 *
 * https://photoswipe.com/adding-ui-elements/
 *
 * @prop {undefined} uiRegister
 * @prop {{ data: UIElementData }} uiElementCreate
 *
 *
 * https://photoswipe.com/events/#initialization-events
 *
 * @prop {undefined} beforeOpen
 * @prop {undefined} firstUpdate
 * @prop {undefined} initialLayout
 * @prop {undefined} change
 * @prop {undefined} afterInit
 * @prop {undefined} bindEvents
 *
 *
 * https://photoswipe.com/events/#opening-or-closing-transition-events
 *
 * @prop {undefined} openingAnimationStart
 * @prop {undefined} openingAnimationEnd
 * @prop {undefined} closingAnimationStart
 * @prop {undefined} closingAnimationEnd
 *
 *
 * https://photoswipe.com/events/#closing-events
 *
 * @prop {undefined} close
 * @prop {undefined} destroy
 *
 *
 * https://photoswipe.com/events/#pointer-and-gesture-events
 *
 * @prop {{ originalEvent: PointerEvent }} pointerDown
 * @prop {{ originalEvent: PointerEvent }} pointerMove
 * @prop {{ originalEvent: PointerEvent }} pointerUp
 * @prop {{ bgOpacity: number }} pinchClose can be default prevented
 * @prop {{ panY: number }} verticalDrag can be default prevented
 *
 *
 * https://photoswipe.com/events/#slide-content-events
 *
 * @prop {{ content: Content }} contentInit
 * @prop {{ content: Content; isLazy: boolean }} contentLoad can be default prevented
 * @prop {{ content: Content; isLazy: boolean }} contentLoadImage can be default prevented
 * @prop {{ content: Content; slide: Slide; isError?: boolean }} loadComplete
 * @prop {{ content: Content; slide: Slide }} loadError
 * @prop {{ content: Content; width: number; height: number }} contentResize can be default prevented
 * @prop {{ content: Content; width: number; height: number; slide: Slide }} imageSizeChange
 * @prop {{ content: Content }} contentLazyLoad can be default prevented
 * @prop {{ content: Content }} contentAppend can be default prevented
 * @prop {{ content: Content }} contentActivate can be default prevented
 * @prop {{ content: Content }} contentDeactivate can be default prevented
 * @prop {{ content: Content }} contentRemove can be default prevented
 * @prop {{ content: Content }} contentDestroy can be default prevented
 *
 *
 * undocumented
 *
 * @prop {{ point: Point; originalEvent: PointerEvent }} imageClickAction can be default prevented
 * @prop {{ point: Point; originalEvent: PointerEvent }} bgClickAction can be default prevented
 * @prop {{ point: Point; originalEvent: PointerEvent }} tapAction can be default prevented
 * @prop {{ point: Point; originalEvent: PointerEvent }} doubleTapAction can be default prevented
 *
 * @prop {{ originalEvent: KeyboardEvent }} keydown can be default prevented
 * @prop {{ x: number; dragging: boolean }} moveMainScroll
 * @prop {{ slide: Slide }} firstZoomPan
 * @prop {{ slide: Slide | undefined, data: SlideData, index: number }} gettingData
 * @prop {undefined} beforeResize
 * @prop {undefined} resize
 * @prop {undefined} viewportSize
 * @prop {undefined} updateScrollOffset
 * @prop {{ slide: Slide }} slideInit
 * @prop {{ slide: Slide }} afterSetContent
 * @prop {{ slide: Slide }} slideLoad
 * @prop {{ slide: Slide }} appendHeavy can be default prevented
 * @prop {{ slide: Slide }} appendHeavyContent
 * @prop {{ slide: Slide }} slideActivate
 * @prop {{ slide: Slide }} slideDeactivate
 * @prop {{ slide: Slide }} slideDestroy
 * @prop {{ destZoomLevel: number, centerPoint: Point | undefined, transitionDuration: number | false | undefined }} beforeZoomTo
 * @prop {{ slide: Slide }} zoomPanUpdate
 * @prop {{ slide: Slide }} initialZoomPan
 * @prop {{ slide: Slide }} calcSlideSize
 * @prop {undefined} resolutionChanged
 * @prop {{ originalEvent: WheelEvent }} wheel can be default prevented
 * @prop {{ content: Content }} contentAppendImage can be default prevented
 * @prop {{ index: number; itemData: SlideData }} lazyLoadSlide can be default prevented
 * @prop {undefined} lazyLoad
 * @prop {{ slide: Slide }} calcBounds
 * @prop {{ zoomLevels: ZoomLevel, slideData: SlideData }} zoomLevelsUpdate
 *
 *
 * legacy
 *
 * @prop {undefined} init
 * @prop {undefined} initialZoomIn
 * @prop {undefined} initialZoomOut
 * @prop {undefined} initialZoomInEnd
 * @prop {undefined} initialZoomOutEnd
 * @prop {{ dataSource: DataSource | undefined, numItems: number }} numItems
 * @prop {{ itemData: SlideData; index: number }} itemData
 * @prop {{ index: number, itemData: SlideData, instance: PhotoSwipe }} thumbBounds
 */
/**
 * @typedef {Object} PhotoSwipeFiltersMap https://photoswipe.com/filters/
 *
 * @prop {(numItems: number, dataSource: DataSource | undefined) => number} numItems
 * Modify the total amount of slides. Example on Data sources page.
 * https://photoswipe.com/filters/#numitems
 *
 * @prop {(itemData: SlideData, index: number) => SlideData} itemData
 * Modify slide item data. Example on Data sources page.
 * https://photoswipe.com/filters/#itemdata
 *
 * @prop {(itemData: SlideData, element: HTMLElement, linkEl: HTMLAnchorElement) => SlideData} domItemData
 * Modify item data when it's parsed from DOM element. Example on Data sources page.
 * https://photoswipe.com/filters/#domitemdata
 *
 * @prop {(clickedIndex: number, e: MouseEvent, instance: PhotoSwipeLightbox) => number} clickedIndex
 * Modify clicked gallery item index.
 * https://photoswipe.com/filters/#clickedindex
 *
 * @prop {(placeholderSrc: string | false, content: Content) => string | false} placeholderSrc
 * Modify placeholder image source.
 * https://photoswipe.com/filters/#placeholdersrc
 *
 * @prop {(isContentLoading: boolean, content: Content) => boolean} isContentLoading
 * Modify if the content is currently loading.
 * https://photoswipe.com/filters/#iscontentloading
 *
 * @prop {(isContentZoomable: boolean, content: Content) => boolean} isContentZoomable
 * Modify if the content can be zoomed.
 * https://photoswipe.com/filters/#iscontentzoomable
 *
 * @prop {(useContentPlaceholder: boolean, content: Content) => boolean} useContentPlaceholder
 * Modify if the placeholder should be used for the content.
 * https://photoswipe.com/filters/#usecontentplaceholder
 *
 * @prop {(isKeepingPlaceholder: boolean, content: Content) => boolean} isKeepingPlaceholder
 * Modify if the placeholder should be kept after the content is loaded.
 * https://photoswipe.com/filters/#iskeepingplaceholder
 *
 *
 * @prop {(contentErrorElement: HTMLElement, content: Content) => HTMLElement} contentErrorElement
 * Modify an element when the content has error state (for example, if image cannot be loaded).
 * https://photoswipe.com/filters/#contenterrorelement
 *
 * @prop {(element: HTMLElement, data: UIElementData) => HTMLElement} uiElement
 * Modify a UI element that's being created.
 * https://photoswipe.com/filters/#uielement
 *
 * @prop {(thumbnail: HTMLElement | null | undefined, itemData: SlideData, index: number) => HTMLElement} thumbEl
 * Modify the thumbnail element from which opening zoom animation starts or ends.
 * https://photoswipe.com/filters/#thumbel
 *
 * @prop {(thumbBounds: Bounds | undefined, itemData: SlideData, index: number) => Bounds} thumbBounds
 * Modify the thumbnail bounds from which opening zoom animation starts or ends.
 * https://photoswipe.com/filters/#thumbbounds
 *
 * @prop {(srcsetSizesWidth: number, content: Content) => number} srcsetSizesWidth
 *
 * @prop {(preventPointerEvent: boolean, event: PointerEvent, pointerType: string) => boolean} preventPointerEvent
 *
 */
/**
 * @template {keyof PhotoSwipeFiltersMap} T
 * @typedef {{ fn: PhotoSwipeFiltersMap[T], priority: number }} Filter
 */
/**
 * @template {keyof PhotoSwipeEventsMap} T
 * @typedef {PhotoSwipeEventsMap[T] extends undefined ? PhotoSwipeEvent<T> : PhotoSwipeEvent<T> & PhotoSwipeEventsMap[T]} AugmentedEvent
 */
/**
 * @template {keyof PhotoSwipeEventsMap} T
 * @typedef {(event: AugmentedEvent<T>) => void} EventCallback
 */
/**
 * Base PhotoSwipe event object
 *
 * @template {keyof PhotoSwipeEventsMap} T
 */class PhotoSwipeEvent{
/**
   * @param {T} type
   * @param {PhotoSwipeEventsMap[T]} [details]
   */
constructor(t,e){this.type=t;this.defaultPrevented=false;e&&Object.assign(this,e)}preventDefault(){this.defaultPrevented=true}}class Eventable{constructor(){
/**
     * @type {{ [T in keyof PhotoSwipeEventsMap]?: ((event: AugmentedEvent<T>) => void)[] }}
     */
this._listeners={};
/**
     * @type {{ [T in keyof PhotoSwipeFiltersMap]?: Filter<T>[] }}
     */this._filters={};
/** @type {PhotoSwipe | undefined} */this.pswp=void 0;
/** @type {PhotoSwipeOptions | undefined} */this.options=void 0}
/**
   * @template {keyof PhotoSwipeFiltersMap} T
   * @param {T} name
   * @param {PhotoSwipeFiltersMap[T]} fn
   * @param {number} priority
   */addFilter(t,e,i=100){var s,n,o;this._filters[t]||(this._filters[t]=[]);(s=this._filters[t])===null||s===void 0||s.push({fn:e,priority:i});(n=this._filters[t])===null||n===void 0||n.sort(((t,e)=>t.priority-e.priority));(o=this.pswp)===null||o===void 0||o.addFilter(t,e,i)}
/**
   * @template {keyof PhotoSwipeFiltersMap} T
   * @param {T} name
   * @param {PhotoSwipeFiltersMap[T]} fn
   */removeFilter(t,e){this._filters[t]&&(this._filters[t]=this._filters[t].filter((t=>t.fn!==e)));this.pswp&&this.pswp.removeFilter(t,e)}
/**
   * @template {keyof PhotoSwipeFiltersMap} T
   * @param {T} name
   * @param {Parameters<PhotoSwipeFiltersMap[T]>} args
   * @returns {Parameters<PhotoSwipeFiltersMap[T]>[0]}
   */applyFilters(t,...e){var i;(i=this._filters[t])===null||i===void 0||i.forEach((t=>{e[0]=t.fn.apply(this,e)}));return e[0]}
/**
   * @template {keyof PhotoSwipeEventsMap} T
   * @param {T} name
   * @param {EventCallback<T>} fn
   */on(t,e){var i,s;this._listeners[t]||(this._listeners[t]=[]);(i=this._listeners[t])===null||i===void 0||i.push(e);(s=this.pswp)===null||s===void 0||s.on(t,e)}
/**
   * @template {keyof PhotoSwipeEventsMap} T
   * @param {T} name
   * @param {EventCallback<T>} fn
   */off(t,e){var i;this._listeners[t]&&(this._listeners[t]=this._listeners[t].filter((t=>e!==t)));(i=this.pswp)===null||i===void 0||i.off(t,e)}
/**
   * @template {keyof PhotoSwipeEventsMap} T
   * @param {T} name
   * @param {PhotoSwipeEventsMap[T]} [details]
   * @returns {AugmentedEvent<T>}
   */dispatch(t,e){var i;if(this.pswp)return this.pswp.dispatch(t,e);const s=
/** @type {AugmentedEvent<T>} */
new PhotoSwipeEvent(t,e);(i=this._listeners[t])===null||i===void 0||i.forEach((t=>{t.call(this,s)}));return s}}class Placeholder{
/**
   * @param {string | false} imageSrc
   * @param {HTMLElement} container
   */
constructor(t,e){
/** @type {HTMLImageElement | HTMLDivElement | null} */
this.element=createElement("pswp__img pswp__img--placeholder",t?"img":"div",e);if(t){const e=
/** @type {HTMLImageElement} */
this.element;e.decoding="async";e.alt="";e.src=t;e.setAttribute("role","presentation")}this.element.setAttribute("aria-hidden","true")}
/**
   * @param {number} width
   * @param {number} height
   */setDisplayedSize(t,e){if(this.element)if(this.element.tagName==="IMG"){setWidthHeight(this.element,250,"auto");this.element.style.transformOrigin="0 0";this.element.style.transform=toTransformString(0,0,t/250)}else setWidthHeight(this.element,t,e)}destroy(){var t;(t=this.element)!==null&&t!==void 0&&t.parentNode&&this.element.remove();this.element=null}}
/** @typedef {import('./slide.js').default} Slide */
/** @typedef {import('./slide.js').SlideData} SlideData */
/** @typedef {import('../core/base.js').default} PhotoSwipeBase */
/** @typedef {import('../util/util.js').LoadState} LoadState */class Content{
/**
   * @param {SlideData} itemData Slide data
   * @param {PhotoSwipeBase} instance PhotoSwipe or PhotoSwipeLightbox instance
   * @param {number} index
   */
constructor(t,i,s){this.instance=i;this.data=t;this.index=s;
/** @type {HTMLImageElement | HTMLDivElement | undefined} */this.element=void 0;
/** @type {Placeholder | undefined} */this.placeholder=void 0;
/** @type {Slide | undefined} */this.slide=void 0;this.displayedImageWidth=0;this.displayedImageHeight=0;this.width=Number(this.data.w)||Number(this.data.width)||0;this.height=Number(this.data.h)||Number(this.data.height)||0;this.isAttached=false;this.hasSlide=false;this.isDecoding=false;
/** @type {LoadState} */this.state=e.IDLE;this.data.type?this.type=this.data.type:this.data.src?this.type="image":this.type="html";this.instance.dispatch("contentInit",{content:this})}removePlaceholder(){this.placeholder&&!this.keepPlaceholder()&&setTimeout((()=>{if(this.placeholder){this.placeholder.destroy();this.placeholder=void 0}}),1e3)}
/**
   * Preload content
   *
   * @param {boolean} isLazy
   * @param {boolean} [reload]
   */load(t,e){if(this.slide&&this.usePlaceholder())if(this.placeholder){const t=this.placeholder.element;t&&!t.parentElement&&this.slide.container.prepend(t)}else{const t=this.instance.applyFilters("placeholderSrc",!(!this.data.msrc||!this.slide.isFirstSlide)&&this.data.msrc,this);this.placeholder=new Placeholder(t,this.slide.container)}if((!this.element||e)&&!this.instance.dispatch("contentLoad",{content:this,isLazy:t}).defaultPrevented){if(this.isImageContent()){this.element=createElement("pswp__img","img");this.displayedImageWidth&&this.loadImage(t)}else{this.element=createElement("pswp__content","div");this.element.innerHTML=this.data.html||""}e&&this.slide&&this.slide.updateContentSize(true)}}
/**
   * Preload image
   *
   * @param {boolean} isLazy
   */loadImage(t){var i,s;if(!this.isImageContent()||!this.element||this.instance.dispatch("contentLoadImage",{content:this,isLazy:t}).defaultPrevented)return;const n=
/** @type HTMLImageElement */
this.element;this.updateSrcsetSizes();this.data.srcset&&(n.srcset=this.data.srcset);n.src=(i=this.data.src)!==null&&i!==void 0?i:"";n.alt=(s=this.data.alt)!==null&&s!==void 0?s:"";this.state=e.LOADING;if(n.complete)this.onLoaded();else{n.onload=()=>{this.onLoaded()};n.onerror=()=>{this.onError()}}}
/**
   * Assign slide to content
   *
   * @param {Slide} slide
   */setSlide(t){this.slide=t;this.hasSlide=true;this.instance=t.pswp}onLoaded(){this.state=e.LOADED;if(this.slide&&this.element){this.instance.dispatch("loadComplete",{slide:this.slide,content:this});if(this.slide.isActive&&this.slide.heavyAppended&&!this.element.parentNode){this.append();this.slide.updateContentSize(true)}this.state!==e.LOADED&&this.state!==e.ERROR||this.removePlaceholder()}}onError(){this.state=e.ERROR;if(this.slide){this.displayError();this.instance.dispatch("loadComplete",{slide:this.slide,isError:true,content:this});this.instance.dispatch("loadError",{slide:this.slide,content:this})}}
/**
   * @returns {Boolean} If the content is currently loading
   */isLoading(){return this.instance.applyFilters("isContentLoading",this.state===e.LOADING,this)}
/**
   * @returns {Boolean} If the content is in error state
   */isError(){return this.state===e.ERROR}
/**
   * @returns {boolean} If the content is image
   */isImageContent(){return this.type==="image"}
/**
   * Update content size
   *
   * @param {Number} width
   * @param {Number} height
   */setDisplayedSize(t,e){if(this.element){this.placeholder&&this.placeholder.setDisplayedSize(t,e);if(!this.instance.dispatch("contentResize",{content:this,width:t,height:e}).defaultPrevented){setWidthHeight(this.element,t,e);if(this.isImageContent()&&!this.isError()){const i=!this.displayedImageWidth&&t;this.displayedImageWidth=t;this.displayedImageHeight=e;i?this.loadImage(false):this.updateSrcsetSizes();this.slide&&this.instance.dispatch("imageSizeChange",{slide:this.slide,width:t,height:e,content:this})}}}}
/**
   * @returns {boolean} If the content can be zoomed
   */isZoomable(){return this.instance.applyFilters("isContentZoomable",this.isImageContent()&&this.state!==e.ERROR,this)}updateSrcsetSizes(){if(!this.isImageContent()||!this.element||!this.data.srcset)return;const t=
/** @type HTMLImageElement */
this.element;const e=this.instance.applyFilters("srcsetSizesWidth",this.displayedImageWidth,this);if(!t.dataset.largestUsedSize||e>parseInt(t.dataset.largestUsedSize,10)){t.sizes=e+"px";t.dataset.largestUsedSize=String(e)}}
/**
   * @returns {boolean} If content should use a placeholder (from msrc by default)
   */usePlaceholder(){return this.instance.applyFilters("useContentPlaceholder",this.isImageContent(),this)}lazyLoad(){this.instance.dispatch("contentLazyLoad",{content:this}).defaultPrevented||this.load(true)}
/**
   * @returns {boolean} If placeholder should be kept after content is loaded
   */keepPlaceholder(){return this.instance.applyFilters("isKeepingPlaceholder",this.isLoading(),this)}destroy(){this.hasSlide=false;this.slide=void 0;if(!this.instance.dispatch("contentDestroy",{content:this}).defaultPrevented){this.remove();if(this.placeholder){this.placeholder.destroy();this.placeholder=void 0}if(this.isImageContent()&&this.element){this.element.onload=null;this.element.onerror=null;this.element=void 0}}}displayError(){if(this.slide){var t,e;let i=createElement("pswp__error-msg","div");i.innerText=(t=(e=this.instance.options)===null||e===void 0?void 0:e.errorMsg)!==null&&t!==void 0?t:"";i=
/** @type {HTMLDivElement} */
this.instance.applyFilters("contentErrorElement",i,this);this.element=createElement("pswp__content pswp__error-msg-container","div");this.element.appendChild(i);this.slide.container.innerText="";this.slide.container.appendChild(this.element);this.slide.updateContentSize(true);this.removePlaceholder()}}append(){if(this.isAttached||!this.element)return;this.isAttached=true;if(this.state===e.ERROR){this.displayError();return}if(this.instance.dispatch("contentAppend",{content:this}).defaultPrevented)return;const t="decode"in this.element;if(this.isImageContent())if(t&&this.slide&&(!this.slide.isActive||isSafari())){this.isDecoding=true;
/** @type {HTMLImageElement} */this.element.decode().catch((()=>{})).finally((()=>{this.isDecoding=false;this.appendImage()}))}else this.appendImage();else this.slide&&!this.element.parentNode&&this.slide.container.appendChild(this.element)}activate(){if(!this.instance.dispatch("contentActivate",{content:this}).defaultPrevented&&this.slide){this.isImageContent()&&this.isDecoding&&!isSafari()?this.appendImage():this.isError()&&this.load(false,true);this.slide.holderElement&&this.slide.holderElement.setAttribute("aria-hidden","false")}}deactivate(){this.instance.dispatch("contentDeactivate",{content:this});this.slide&&this.slide.holderElement&&this.slide.holderElement.setAttribute("aria-hidden","true")}remove(){this.isAttached=false;if(!this.instance.dispatch("contentRemove",{content:this}).defaultPrevented){this.element&&this.element.parentNode&&this.element.remove();this.placeholder&&this.placeholder.element&&this.placeholder.element.remove()}}appendImage(){if(this.isAttached&&!this.instance.dispatch("contentAppendImage",{content:this}).defaultPrevented){this.slide&&this.element&&!this.element.parentNode&&this.slide.container.appendChild(this.element);this.state!==e.LOADED&&this.state!==e.ERROR||this.removePlaceholder()}}}
/** @typedef {import('./content.js').default} Content */
/** @typedef {import('./slide.js').default} Slide */
/** @typedef {import('./slide.js').SlideData} SlideData */
/** @typedef {import('../core/base.js').default} PhotoSwipeBase */
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */const z=5;
/**
 * Lazy-load an image
 * This function is used both by Lightbox and PhotoSwipe core,
 * thus it can be called before dialog is opened.
 *
 * @param {SlideData} itemData Data about the slide
 * @param {PhotoSwipeBase} instance PhotoSwipe or PhotoSwipeLightbox instance
 * @param {number} index
 * @returns {Content} Image that is being decoded or false.
 */function lazyLoadData(t,e,i){const s=e.createContentFromData(t,i);
/** @type {ZoomLevel | undefined} */let n;const{options:o}=e;if(o){n=new ZoomLevel(o,t,-1);let a;a=e.pswp?e.pswp.viewportSize:getViewportSize(o,e);const r=getPanAreaSize(o,a,t,i);n.update(s.width,s.height,r)}s.lazyLoad();n&&s.setDisplayedSize(Math.ceil(s.width*n.initial),Math.ceil(s.height*n.initial));return s}
/**
 * Lazy-loads specific slide.
 * This function is used both by Lightbox and PhotoSwipe core,
 * thus it can be called before dialog is opened.
 *
 * By default, it loads image based on viewport size and initial zoom level.
 *
 * @param {number} index Slide index
 * @param {PhotoSwipeBase} instance PhotoSwipe or PhotoSwipeLightbox eventable instance
 * @returns {Content | undefined}
 */function lazyLoadSlide(t,e){const i=e.getItemData(t);if(!e.dispatch("lazyLoadSlide",{index:t,itemData:i}).defaultPrevented)return lazyLoadData(i,e,t)}class ContentLoader{
/**
   * @param {PhotoSwipe} pswp
   */
constructor(t){this.pswp=t;this.limit=Math.max(t.options.preload[0]+t.options.preload[1]+1,z);
/** @type {Content[]} */this._cachedItems=[]}
/**
   * Lazy load nearby slides based on `preload` option.
   *
   * @param {number} [diff] Difference between slide indexes that was changed recently, or 0.
   */updateLazy(t){const{pswp:e}=this;if(e.dispatch("lazyLoad").defaultPrevented)return;const{preload:i}=e.options;const s=t===void 0||t>=0;let n;for(n=0;n<=i[1];n++)this.loadSlideByIndex(e.currIndex+(s?n:-n));for(n=1;n<=i[0];n++)this.loadSlideByIndex(e.currIndex+(s?-n:n))}
/**
   * @param {number} initialIndex
   */loadSlideByIndex(t){const e=this.pswp.getLoopedIndex(t);let i=this.getContentByIndex(e);if(!i){i=lazyLoadSlide(e,this.pswp);i&&this.addToCache(i)}}
/**
   * @param {Slide} slide
   * @returns {Content}
   */getContentBySlide(t){let e=this.getContentByIndex(t.index);if(!e){e=this.pswp.createContentFromData(t.data,t.index);this.addToCache(e)}e.setSlide(t);return e}
/**
   * @param {Content} content
   */addToCache(t){this.removeByIndex(t.index);this._cachedItems.push(t);if(this._cachedItems.length>this.limit){const t=this._cachedItems.findIndex((t=>!t.isAttached&&!t.hasSlide));if(t!==-1){const e=this._cachedItems.splice(t,1)[0];e.destroy()}}}
/**
   * Removes an image from cache, does not destroy() it, just removes.
   *
   * @param {number} index
   */removeByIndex(t){const e=this._cachedItems.findIndex((e=>e.index===t));e!==-1&&this._cachedItems.splice(e,1)}
/**
   * @param {number} index
   * @returns {Content | undefined}
   */getContentByIndex(t){return this._cachedItems.find((e=>e.index===t))}destroy(){this._cachedItems.forEach((t=>t.destroy()));this._cachedItems=[]}}
/** @typedef {import("../photoswipe.js").default} PhotoSwipe */
/** @typedef {import("../slide/slide.js").SlideData} SlideData */class PhotoSwipeBase extends Eventable{
/**
   * Get total number of slides
   *
   * @returns {number}
   */
getNumItems(){var t;let e=0;const i=(t=this.options)===null||t===void 0?void 0:t.dataSource;if(i&&"length"in i)e=i.length;else if(i&&"gallery"in i){i.items||(i.items=this._getGalleryDOMElements(i.gallery));i.items&&(e=i.items.length)}const s=this.dispatch("numItems",{dataSource:i,numItems:e});return this.applyFilters("numItems",s.numItems,i)}
/**
   * @param {SlideData} slideData
   * @param {number} index
   * @returns {Content}
   */createContentFromData(t,e){return new Content(t,this,e)}
/**
   * Get item data by index.
   *
   * "item data" should contain normalized information that PhotoSwipe needs to generate a slide.
   * For example, it may contain properties like
   * `src`, `srcset`, `w`, `h`, which will be used to generate a slide with image.
   *
   * @param {number} index
   * @returns {SlideData}
   */getItemData(t){var e;const i=(e=this.options)===null||e===void 0?void 0:e.dataSource;
/** @type {SlideData | HTMLElement} */let s={};if(Array.isArray(i))s=i[t];else if(i&&"gallery"in i){i.items||(i.items=this._getGalleryDOMElements(i.gallery));s=i.items[t]}let n=s;n instanceof Element&&(n=this._domElementToItemData(n));const o=this.dispatch("itemData",{itemData:n||{},index:t});return this.applyFilters("itemData",o.itemData,t)}
/**
   * Get array of gallery DOM elements,
   * based on childSelector and gallery element.
   *
   * @param {HTMLElement} galleryElement
   * @returns {HTMLElement[]}
   */_getGalleryDOMElements(t){var e,i;return(e=this.options)!==null&&e!==void 0&&e.children||(i=this.options)!==null&&i!==void 0&&i.childSelector?getElementsFromOption(this.options.children,this.options.childSelector,t)||[]:[t]}
/**
   * Converts DOM element to item data object.
   *
   * @param {HTMLElement} element DOM element
   * @returns {SlideData}
   */_domElementToItemData(t){
/** @type {SlideData} */
const e={element:t};const i=
/** @type {HTMLAnchorElement} */
t.tagName==="A"?t:t.querySelector("a");if(i){e.src=i.dataset.pswpSrc||i.href;i.dataset.pswpSrcset&&(e.srcset=i.dataset.pswpSrcset);e.width=i.dataset.pswpWidth?parseInt(i.dataset.pswpWidth,10):0;e.height=i.dataset.pswpHeight?parseInt(i.dataset.pswpHeight,10):0;e.w=e.width;e.h=e.height;i.dataset.pswpType&&(e.type=i.dataset.pswpType);const n=t.querySelector("img");if(n){var s;e.msrc=n.currentSrc||n.src;e.alt=(s=n.getAttribute("alt"))!==null&&s!==void 0?s:""}(i.dataset.pswpCropped||i.dataset.cropped)&&(e.thumbCropped=true)}return this.applyFilters("domItemData",e,t,i)}
/**
   * Lazy-load by slide data
   *
   * @param {SlideData} itemData Data about the slide
   * @param {number} index
   * @returns {Content} Image that is being decoded or false.
   */lazyLoadData(t,e){return lazyLoadData(t,this,e)}}
/** @typedef {import('./photoswipe.js').default} PhotoSwipe */
/** @typedef {import('./slide/get-thumb-bounds.js').Bounds} Bounds */
/** @typedef {import('./util/animations.js').AnimationProps} AnimationProps */const b=.003;class Opener{
/**
   * @param {PhotoSwipe} pswp
   */
constructor(t){this.pswp=t;this.isClosed=true;this.isOpen=false;this.isClosing=false;this.isOpening=false;
/**
     * @private
     * @type {number | false | undefined}
     */this._duration=void 0;this._useAnimation=false;this._croppedZoom=false;this._animateRootOpacity=false;this._animateBgOpacity=false;
/**
     * @private
     * @type { HTMLDivElement | HTMLImageElement | null | undefined }
     */this._placeholder=void 0;
/**
     * @private
     * @type { HTMLDivElement | undefined }
     */this._opacityElement=void 0;
/**
     * @private
     * @type { HTMLDivElement | undefined }
     */this._cropContainer1=void 0;
/**
     * @private
     * @type { HTMLElement | null | undefined }
     */this._cropContainer2=void 0;
/**
     * @private
     * @type {Bounds | undefined}
     */this._thumbBounds=void 0;this._prepareOpen=this._prepareOpen.bind(this);t.on("firstZoomPan",this._prepareOpen)}open(){this._prepareOpen();this._start()}close(){if(this.isClosed||this.isClosing||this.isOpening)return;const t=this.pswp.currSlide;this.isOpen=false;this.isOpening=false;this.isClosing=true;this._duration=this.pswp.options.hideAnimationDuration;t&&t.currZoomLevel*t.width>=this.pswp.options.maxWidthToAnimate&&(this._duration=0);this._applyStartProps();setTimeout((()=>{this._start()}),this._croppedZoom?30:0)}_prepareOpen(){this.pswp.off("firstZoomPan",this._prepareOpen);if(!this.isOpening){const t=this.pswp.currSlide;this.isOpening=true;this.isClosing=false;this._duration=this.pswp.options.showAnimationDuration;t&&t.zoomLevels.initial*t.width>=this.pswp.options.maxWidthToAnimate&&(this._duration=0);this._applyStartProps()}}_applyStartProps(){const{pswp:t}=this;const e=this.pswp.currSlide;const{options:i}=t;if(i.showHideAnimationType==="fade"){i.showHideOpacity=true;this._thumbBounds=void 0}else if(i.showHideAnimationType==="none"){i.showHideOpacity=false;this._duration=0;this._thumbBounds=void 0}else this.isOpening&&t._initialThumbBounds?this._thumbBounds=t._initialThumbBounds:this._thumbBounds=this.pswp.getThumbBounds();this._placeholder=e===null||e===void 0?void 0:e.getPlaceholderElement();t.animations.stopAll();this._useAnimation=Boolean(this._duration&&this._duration>50);this._animateZoom=Boolean(this._thumbBounds)&&(e===null||e===void 0?void 0:e.content.usePlaceholder())&&(!this.isClosing||!t.mainScroll.isShifted());if(this._animateZoom){var s;this._animateRootOpacity=(s=i.showHideOpacity)!==null&&s!==void 0&&s}else{this._animateRootOpacity=true;if(this.isOpening&&e){e.zoomAndPanToInitial();e.applyCurrentZoomPan()}}this._animateBgOpacity=!this._animateRootOpacity&&this.pswp.options.bgOpacity>b;this._opacityElement=this._animateRootOpacity?t.element:t.bg;if(this._useAnimation){if(this._animateZoom&&this._thumbBounds&&this._thumbBounds.innerRect){var n;this._croppedZoom=true;this._cropContainer1=this.pswp.container;this._cropContainer2=(n=this.pswp.currSlide)===null||n===void 0?void 0:n.holderElement;if(t.container){t.container.style.overflow="hidden";t.container.style.width=t.viewportSize.x+"px"}}else this._croppedZoom=false;if(this.isOpening){if(this._animateRootOpacity){t.element&&(t.element.style.opacity=String(b));t.applyBgOpacity(1)}else{this._animateBgOpacity&&t.bg&&(t.bg.style.opacity=String(b));t.element&&(t.element.style.opacity="1")}if(this._animateZoom){this._setClosedStateZoomPan();if(this._placeholder){this._placeholder.style.willChange="transform";this._placeholder.style.opacity=String(b)}}}else if(this.isClosing){t.mainScroll.itemHolders[0]&&(t.mainScroll.itemHolders[0].el.style.display="none");t.mainScroll.itemHolders[2]&&(t.mainScroll.itemHolders[2].el.style.display="none");if(this._croppedZoom&&t.mainScroll.x!==0){t.mainScroll.resetPosition();t.mainScroll.resize()}}}else{this._duration=0;this._animateZoom=false;this._animateBgOpacity=false;this._animateRootOpacity=true;if(this.isOpening){t.element&&(t.element.style.opacity=String(b));t.applyBgOpacity(1)}}}_start(){this.isOpening&&this._useAnimation&&this._placeholder&&this._placeholder.tagName==="IMG"?new Promise((t=>{let e=false;let i=true;decodeImage(
/** @type {HTMLImageElement} */
this._placeholder).finally((()=>{e=true;i||t(true)}));setTimeout((()=>{i=false;e&&t(true)}),50);setTimeout(t,250)})).finally((()=>this._initiate())):this._initiate()}_initiate(){var t,e;(t=this.pswp.element)===null||t===void 0||t.style.setProperty("--pswp-transition-duration",this._duration+"ms");this.pswp.dispatch(this.isOpening?"openingAnimationStart":"closingAnimationStart");this.pswp.dispatch(
/** @type {'initialZoomIn' | 'initialZoomOut'} */
"initialZoom"+(this.isOpening?"In":"Out"));(e=this.pswp.element)===null||e===void 0||e.classList.toggle("pswp--ui-visible",this.isOpening);if(this.isOpening){this._placeholder&&(this._placeholder.style.opacity="1");this._animateToOpenState()}else this.isClosing&&this._animateToClosedState();this._useAnimation||this._onAnimationComplete()}_onAnimationComplete(){const{pswp:t}=this;this.isOpen=this.isOpening;this.isClosed=this.isClosing;this.isOpening=false;this.isClosing=false;t.dispatch(this.isOpen?"openingAnimationEnd":"closingAnimationEnd");t.dispatch(
/** @type {'initialZoomInEnd' | 'initialZoomOutEnd'} */
"initialZoom"+(this.isOpen?"InEnd":"OutEnd"));if(this.isClosed)t.destroy();else if(this.isOpen){var e;if(this._animateZoom&&t.container){t.container.style.overflow="visible";t.container.style.width="100%"}(e=t.currSlide)===null||e===void 0||e.applyCurrentZoomPan()}}_animateToOpenState(){const{pswp:t}=this;if(this._animateZoom){if(this._croppedZoom&&this._cropContainer1&&this._cropContainer2){this._animateTo(this._cropContainer1,"transform","translate3d(0,0,0)");this._animateTo(this._cropContainer2,"transform","none")}if(t.currSlide){t.currSlide.zoomAndPanToInitial();this._animateTo(t.currSlide.container,"transform",t.currSlide.getCurrentTransform())}}this._animateBgOpacity&&t.bg&&this._animateTo(t.bg,"opacity",String(t.options.bgOpacity));this._animateRootOpacity&&t.element&&this._animateTo(t.element,"opacity","1")}_animateToClosedState(){const{pswp:t}=this;this._animateZoom&&this._setClosedStateZoomPan(true);this._animateBgOpacity&&t.bgOpacity>.01&&t.bg&&this._animateTo(t.bg,"opacity","0");this._animateRootOpacity&&t.element&&this._animateTo(t.element,"opacity","0")}
/**
   * @private
   * @param {boolean} [animate]
   */_setClosedStateZoomPan(t){if(!this._thumbBounds)return;const{pswp:e}=this;const{innerRect:i}=this._thumbBounds;const{currSlide:s,viewportSize:n}=e;if(this._croppedZoom&&i&&this._cropContainer1&&this._cropContainer2){const e=-n.x+(this._thumbBounds.x-i.x)+i.w;const s=-n.y+(this._thumbBounds.y-i.y)+i.h;const o=n.x-i.w;const a=n.y-i.h;if(t){this._animateTo(this._cropContainer1,"transform",toTransformString(e,s));this._animateTo(this._cropContainer2,"transform",toTransformString(o,a))}else{setTransform(this._cropContainer1,e,s);setTransform(this._cropContainer2,o,a)}}if(s){equalizePoints(s.pan,i||this._thumbBounds);s.currZoomLevel=this._thumbBounds.w/s.width;t?this._animateTo(s.container,"transform",s.getCurrentTransform()):s.applyCurrentZoomPan()}}
/**
   * @private
   * @param {HTMLElement} target
   * @param {'transform' | 'opacity'} prop
   * @param {string} propValue
   */_animateTo(t,e,i){if(!this._duration){t.style[e]=i;return}const{animations:s}=this.pswp;
/** @type {AnimationProps} */const n={duration:this._duration,easing:this.pswp.options.easing,onComplete:()=>{s.activeAnimations.length||this._onAnimationComplete()},target:t};n[e]=i;s.startTransition(n)}}
/**
 * @template T
 * @typedef {import('./types.js').Type<T>} Type<T>
 */
/** @typedef {import('./slide/slide.js').SlideData} SlideData */
/** @typedef {import('./slide/zoom-level.js').ZoomLevelOption} ZoomLevelOption */
/** @typedef {import('./ui/ui-element.js').UIElementData} UIElementData */
/** @typedef {import('./main-scroll.js').ItemHolder} ItemHolder */
/** @typedef {import('./core/eventable.js').PhotoSwipeEventsMap} PhotoSwipeEventsMap */
/** @typedef {import('./core/eventable.js').PhotoSwipeFiltersMap} PhotoSwipeFiltersMap */
/** @typedef {import('./slide/get-thumb-bounds').Bounds} Bounds */
/**
 * @template {keyof PhotoSwipeEventsMap} T
 * @typedef {import('./core/eventable.js').EventCallback<T>} EventCallback<T>
 */
/**
 * @template {keyof PhotoSwipeEventsMap} T
 * @typedef {import('./core/eventable.js').AugmentedEvent<T>} AugmentedEvent<T>
 */
/** @typedef {{ x: number; y: number; id?: string | number }} Point */
/** @typedef {{ top: number; bottom: number; left: number; right: number }} Padding */
/** @typedef {SlideData[]} DataSourceArray */
/** @typedef {{ gallery: HTMLElement; items?: HTMLElement[] }} DataSourceObject */
/** @typedef {DataSourceArray | DataSourceObject} DataSource */
/** @typedef {(point: Point, originalEvent: PointerEvent) => void} ActionFn */
/** @typedef {'close' | 'next' | 'zoom' | 'zoom-or-close' | 'toggle-controls'} ActionType */
/** @typedef {Type<PhotoSwipe> | { default: Type<PhotoSwipe> }} PhotoSwipeModule */
/** @typedef {PhotoSwipeModule | Promise<PhotoSwipeModule> | (() => Promise<PhotoSwipeModule>)} PhotoSwipeModuleOption */
/**
 * @typedef {string | NodeListOf<HTMLElement> | HTMLElement[] | HTMLElement} ElementProvider
 */
/** @typedef {Partial<PreparedPhotoSwipeOptions>} PhotoSwipeOptions https://photoswipe.com/options/ */
/**
 * @typedef {Object} PreparedPhotoSwipeOptions
 *
 * @prop {DataSource} [dataSource]
 * Pass an array of any items via dataSource option. Its length will determine amount of slides
 * (which may be modified further from numItems event).
 *
 * Each item should contain data that you need to generate slide
 * (for image slide it would be src (image URL), width (image width), height, srcset, alt).
 *
 * If these properties are not present in your initial array, you may "pre-parse" each item from itemData filter.
 *
 * @prop {number} bgOpacity
 * Background backdrop opacity, always define it via this option and not via CSS rgba color.
 *
 * @prop {number} spacing
 * Spacing between slides. Defined as ratio relative to the viewport width (0.1 = 10% of viewport).
 *
 * @prop {boolean} allowPanToNext
 * Allow swipe navigation to the next slide when the current slide is zoomed. Does not apply to mouse events.
 *
 * @prop {boolean} loop
 * If set to true you'll be able to swipe from the last to the first image.
 * Option is always false when there are less than 3 slides.
 *
 * @prop {boolean} [wheelToZoom]
 * By default PhotoSwipe zooms image with ctrl-wheel, if you enable this option - image will zoom just via wheel.
 *
 * @prop {boolean} pinchToClose
 * Pinch touch gesture to close the gallery.
 *
 * @prop {boolean} closeOnVerticalDrag
 * Vertical drag gesture to close the PhotoSwipe.
 *
 * @prop {Padding} [padding]
 * Slide area padding (in pixels).
 *
 * @prop {(viewportSize: Point, itemData: SlideData, index: number) => Padding} [paddingFn]
 * The option is checked frequently, so make sure it's performant. Overrides padding option if defined. For example:
 *
 * @prop {number | false} hideAnimationDuration
 * Transition duration in milliseconds, can be 0.
 *
 * @prop {number | false} showAnimationDuration
 * Transition duration in milliseconds, can be 0.
 *
 * @prop {number | false} zoomAnimationDuration
 * Transition duration in milliseconds, can be 0.
 *
 * @prop {string} easing
 * String, 'cubic-bezier(.4,0,.22,1)'. CSS easing function for open/close/zoom transitions.
 *
 * @prop {boolean} escKey
 * Esc key to close.
 *
 * @prop {boolean} arrowKeys
 * Left/right arrow keys for navigation.
 *
 * @prop {boolean} trapFocus
 * Trap focus within PhotoSwipe element while it's open.
 *
 * @prop {boolean} returnFocus
 * Restore focus the last active element after PhotoSwipe is closed.
 *
 * @prop {boolean} clickToCloseNonZoomable
 * If image is not zoomable (for example, smaller than viewport) it can be closed by clicking on it.
 *
 * @prop {ActionType | ActionFn | false} imageClickAction
 * Refer to click and tap actions page.
 *
 * @prop {ActionType | ActionFn | false} bgClickAction
 * Refer to click and tap actions page.
 *
 * @prop {ActionType | ActionFn | false} tapAction
 * Refer to click and tap actions page.
 *
 * @prop {ActionType | ActionFn | false} doubleTapAction
 * Refer to click and tap actions page.
 *
 * @prop {number} preloaderDelay
 * Delay before the loading indicator will be displayed,
 * if image is loaded during it - the indicator will not be displayed at all. Can be zero.
 *
 * @prop {string} indexIndicatorSep
 * Used for slide count indicator ("1 of 10 ").
 *
 * @prop {(options: PhotoSwipeOptions, pswp: PhotoSwipeBase) => Point} [getViewportSizeFn]
 * A function that should return slide viewport width and height, in format {x: 100, y: 100}.
 *
 * @prop {string} errorMsg
 * Message to display when the image wasn't able to load. If you need to display HTML - use contentErrorElement filter.
 *
 * @prop {[number, number]} preload
 * Lazy loading of nearby slides based on direction of movement. Should be an array with two integers,
 * first one - number of items to preload before the current image, second one - after the current image.
 * Two nearby images are always loaded.
 *
 * @prop {string} [mainClass]
 * Class that will be added to the root element of PhotoSwipe, may contain multiple separated by space.
 * Example on Styling page.
 *
 * @prop {HTMLElement} [appendToEl]
 * Element to which PhotoSwipe dialog will be appended when it opens.
 *
 * @prop {number} maxWidthToAnimate
 * Maximum width of image to animate, if initial rendered image width
 * is larger than this value - the opening/closing transition will be automatically disabled.
 *
 * @prop {string} [closeTitle]
 * Translating
 *
 * @prop {string} [zoomTitle]
 * Translating
 *
 * @prop {string} [arrowPrevTitle]
 * Translating
 *
 * @prop {string} [arrowNextTitle]
 * Translating
 *
 * @prop {'zoom' | 'fade' | 'none'} [showHideAnimationType]
 * To adjust opening or closing transition type use lightbox option `showHideAnimationType` (`String`).
 * It supports three values - `zoom` (default), `fade` (default if there is no thumbnail) and `none`.
 *
 * Animations are automatically disabled if user `(prefers-reduced-motion: reduce)`.
 *
 * @prop {number} index
 * Defines start slide index.
 *
 * @prop {(e: MouseEvent) => number} [getClickedIndexFn]
 *
 * @prop {boolean} [arrowPrev]
 * @prop {boolean} [arrowNext]
 * @prop {boolean} [zoom]
 * @prop {boolean} [close]
 * @prop {boolean} [counter]
 *
 * @prop {string} [arrowPrevSVG]
 * @prop {string} [arrowNextSVG]
 * @prop {string} [zoomSVG]
 * @prop {string} [closeSVG]
 * @prop {string} [counterSVG]
 *
 * @prop {string} [arrowPrevTitle]
 * @prop {string} [arrowNextTitle]
 * @prop {string} [zoomTitle]
 * @prop {string} [closeTitle]
 * @prop {string} [counterTitle]
 *
 * @prop {ZoomLevelOption} [initialZoomLevel]
 * @prop {ZoomLevelOption} [secondaryZoomLevel]
 * @prop {ZoomLevelOption} [maxZoomLevel]
 *
 * @prop {boolean} [mouseMovePan]
 * @prop {Point | null} [initialPointerPos]
 * @prop {boolean} [showHideOpacity]
 *
 * @prop {PhotoSwipeModuleOption} [pswpModule]
 * @prop {() => Promise<any>} [openPromise]
 * @prop {boolean} [preloadFirstSlide]
 * @prop {ElementProvider} [gallery]
 * @prop {string} [gallerySelector]
 * @prop {ElementProvider} [children]
 * @prop {string} [childSelector]
 * @prop {string | false} [thumbSelector]
 */
/** @type {PreparedPhotoSwipeOptions} */const L={allowPanToNext:true,spacing:.1,loop:true,pinchToClose:true,closeOnVerticalDrag:true,hideAnimationDuration:333,showAnimationDuration:333,zoomAnimationDuration:333,escKey:true,arrowKeys:true,trapFocus:true,returnFocus:true,maxWidthToAnimate:4e3,clickToCloseNonZoomable:true,imageClickAction:"zoom-or-close",bgClickAction:"close",tapAction:"toggle-controls",doubleTapAction:"zoom",indexIndicatorSep:" / ",preloaderDelay:2e3,bgOpacity:.8,index:0,errorMsg:"The image cannot be loaded",preload:[1,2],easing:"cubic-bezier(.4,0,.22,1)"};class PhotoSwipe extends PhotoSwipeBase{
/**
   * @param {PhotoSwipeOptions} [options]
   */
constructor(t){super();this.options=this._prepareOptions(t||{});
/**
     * offset of viewport relative to document
     *
     * @type {Point}
     */this.offset={x:0,y:0};
/**
     * @type {Point}
     * @private
     */this._prevViewportSize={x:0,y:0};
/**
     * Size of scrollable PhotoSwipe viewport
     *
     * @type {Point}
     */this.viewportSize={x:0,y:0};this.bgOpacity=1;this.currIndex=0;this.potentialIndex=0;this.isOpen=false;this.isDestroying=false;this.hasMouse=false;
/**
     * @private
     * @type {SlideData}
     */this._initialItemData={};
/** @type {Bounds | undefined} */this._initialThumbBounds=void 0;
/** @type {HTMLDivElement | undefined} */this.topBar=void 0;
/** @type {HTMLDivElement | undefined} */this.element=void 0;
/** @type {HTMLDivElement | undefined} */this.template=void 0;
/** @type {HTMLDivElement | undefined} */this.container=void 0;
/** @type {HTMLElement | undefined} */this.scrollWrap=void 0;
/** @type {Slide | undefined} */this.currSlide=void 0;this.events=new DOMEvents;this.animations=new Animations;this.mainScroll=new MainScroll(this);this.gestures=new Gestures(this);this.opener=new Opener(this);this.keyboard=new Keyboard(this);this.contentLoader=new ContentLoader(this)}
/** @returns {boolean} */init(){if(this.isOpen||this.isDestroying)return false;this.isOpen=true;this.dispatch("init");this.dispatch("beforeOpen");this._createMainStructure();let t="pswp--open";this.gestures.supportsTouch&&(t+=" pswp--touch");this.options.mainClass&&(t+=" "+this.options.mainClass);this.element&&(this.element.className+=" "+t);this.currIndex=this.options.index||0;this.potentialIndex=this.currIndex;this.dispatch("firstUpdate");this.scrollWheel=new ScrollWheel(this);(Number.isNaN(this.currIndex)||this.currIndex<0||this.currIndex>=this.getNumItems())&&(this.currIndex=0);this.gestures.supportsTouch||this.mouseDetected();this.updateSize();this.offset.y=window.pageYOffset;this._initialItemData=this.getItemData(this.currIndex);this.dispatch("gettingData",{index:this.currIndex,data:this._initialItemData,slide:void 0});this._initialThumbBounds=this.getThumbBounds();this.dispatch("initialLayout");this.on("openingAnimationEnd",(()=>{const{itemHolders:t}=this.mainScroll;if(t[0]){t[0].el.style.display="block";this.setContent(t[0],this.currIndex-1)}if(t[2]){t[2].el.style.display="block";this.setContent(t[2],this.currIndex+1)}this.appendHeavy();this.contentLoader.updateLazy();this.events.add(window,"resize",this._handlePageResize.bind(this));this.events.add(window,"scroll",this._updatePageScrollOffset.bind(this));this.dispatch("bindEvents")}));this.mainScroll.itemHolders[1]&&this.setContent(this.mainScroll.itemHolders[1],this.currIndex);this.dispatch("change");this.opener.open();this.dispatch("afterInit");return true}
/**
   * Get looped slide index
   * (for example, -1 will return the last slide)
   *
   * @param {number} index
   * @returns {number}
   */getLoopedIndex(t){const e=this.getNumItems();if(this.options.loop){t>e-1&&(t-=e);t<0&&(t+=e)}return clamp(t,0,e-1)}appendHeavy(){this.mainScroll.itemHolders.forEach((t=>{var e;(e=t.slide)===null||e===void 0||e.appendHeavy()}))}
/**
   * Change the slide
   * @param {number} index New index
   */goTo(t){this.mainScroll.moveIndexBy(this.getLoopedIndex(t)-this.potentialIndex)}next(){this.goTo(this.potentialIndex+1)}prev(){this.goTo(this.potentialIndex-1)}
/**
   * @see slide/slide.js zoomTo
   *
   * @param {Parameters<Slide['zoomTo']>} args
   */zoomTo(...t){var e;(e=this.currSlide)===null||e===void 0||e.zoomTo(...t)}toggleZoom(){var t;(t=this.currSlide)===null||t===void 0||t.toggleZoom()}close(){if(this.opener.isOpen&&!this.isDestroying){this.isDestroying=true;this.dispatch("close");this.events.removeAll();this.opener.close()}}destroy(){var t;if(this.isDestroying){this.dispatch("destroy");this._listeners={};if(this.scrollWrap){this.scrollWrap.ontouchmove=null;this.scrollWrap.ontouchend=null}(t=this.element)===null||t===void 0||t.remove();this.mainScroll.itemHolders.forEach((t=>{var e;(e=t.slide)===null||e===void 0||e.destroy()}));this.contentLoader.destroy();this.events.removeAll()}else{this.options.showHideAnimationType="none";this.close()}}
/**
   * Refresh/reload content of a slide by its index
   *
   * @param {number} slideIndex
   */refreshSlideContent(t){this.contentLoader.removeByIndex(t);this.mainScroll.itemHolders.forEach(((e,i)=>{var s,n;let o=((s=(n=this.currSlide)===null||n===void 0?void 0:n.index)!==null&&s!==void 0?s:0)-1+i;this.canLoop()&&(o=this.getLoopedIndex(o));if(o===t){this.setContent(e,t,true);if(i===1){var a;this.currSlide=e.slide;(a=e.slide)===null||a===void 0||a.setIsActive(true)}}}));this.dispatch("change")}
/**
   * Set slide content
   *
   * @param {ItemHolder} holder mainScroll.itemHolders array item
   * @param {number} index Slide index
   * @param {boolean} [force] If content should be set even if index wasn't changed
   */setContent(t,e,i){this.canLoop()&&(e=this.getLoopedIndex(e));if(t.slide){if(t.slide.index===e&&!i)return;t.slide.destroy();t.slide=void 0}if(!this.canLoop()&&(e<0||e>=this.getNumItems()))return;const s=this.getItemData(e);t.slide=new Slide(s,e,this);e===this.currIndex&&(this.currSlide=t.slide);t.slide.append(t.el)}
/** @returns {Point} */getViewportCenterPoint(){return{x:this.viewportSize.x/2,y:this.viewportSize.y/2}}
/**
   * Update size of all elements.
   * Executed on init and on page resize.
   *
   * @param {boolean} [force] Update size even if size of viewport was not changed.
   */updateSize(t){if(this.isDestroying)return;const e=getViewportSize(this.options,this);if(t||!pointsEqual(e,this._prevViewportSize)){equalizePoints(this._prevViewportSize,e);this.dispatch("beforeResize");equalizePoints(this.viewportSize,this._prevViewportSize);this._updatePageScrollOffset();this.dispatch("viewportSize");this.mainScroll.resize(this.opener.isOpen);!this.hasMouse&&window.matchMedia("(any-hover: hover)").matches&&this.mouseDetected();this.dispatch("resize")}}
/**
   * @param {number} opacity
   */applyBgOpacity(t){this.bgOpacity=Math.max(t,0);this.bg&&(this.bg.style.opacity=String(this.bgOpacity*this.options.bgOpacity))}mouseDetected(){if(!this.hasMouse){var t;this.hasMouse=true;(t=this.element)===null||t===void 0||t.classList.add("pswp--has_mouse")}}_handlePageResize(){this.updateSize();/iPhone|iPad|iPod/i.test(window.navigator.userAgent)&&setTimeout((()=>{this.updateSize()}),500)}_updatePageScrollOffset(){this.setScrollOffset(0,window.pageYOffset)}
/**
   * @param {number} x
   * @param {number} y
   */setScrollOffset(t,e){this.offset.x=t;this.offset.y=e;this.dispatch("updateScrollOffset")}_createMainStructure(){this.element=createElement("pswp","div");this.element.setAttribute("tabindex","-1");this.element.setAttribute("role","dialog");this.template=this.element;this.bg=createElement("pswp__bg","div",this.element);this.scrollWrap=createElement("pswp__scroll-wrap","section",this.element);this.container=createElement("pswp__container","div",this.scrollWrap);this.scrollWrap.setAttribute("aria-roledescription","carousel");this.container.setAttribute("aria-live","off");this.container.setAttribute("id","pswp__items");this.mainScroll.appendHolders();this.ui=new UI(this);this.ui.init();(this.options.appendToEl||document.body).appendChild(this.element)}
/**
   * Get position and dimensions of small thumbnail
   *   {x:,y:,w:}
   *
   * Height is optional (calculated based on the large image)
   *
   * @returns {Bounds | undefined}
   */getThumbBounds(){return getThumbBounds(this.currIndex,this.currSlide?this.currSlide.data:this._initialItemData,this)}
/**
   * If the PhotoSwipe can have continuous loop
   * @returns Boolean
   */canLoop(){return this.options.loop&&this.getNumItems()>2}
/**
   * @private
   * @param {PhotoSwipeOptions} options
   * @returns {PreparedPhotoSwipeOptions}
   */_prepareOptions(t){if(window.matchMedia("(prefers-reduced-motion), (update: slow)").matches){t.showHideAnimationType="none";t.zoomAnimationDuration=0}
/** @type {PreparedPhotoSwipeOptions} */return{...L,...t}}}export{PhotoSwipe as default};

