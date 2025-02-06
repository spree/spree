// photoswipe/dist/photoswipe-lightbox.esm.js@5.4.4 downloaded from https://ga.jspm.io/npm:photoswipe@5.4.4/dist/photoswipe-lightbox.esm.js

/** @typedef {import('../photoswipe.js').Point} Point */
/**
 * @template {keyof HTMLElementTagNameMap} T
 * @param {string} className
 * @param {T} tagName
 * @param {Node} [appendToEl]
 * @returns {HTMLElementTagNameMap[T]}
 */
function createElement(t, e, i) { const s = document.createElement(e); t && (s.className = t); i && i.appendChild(s); return s }
/**
 * Get transform string
 *
 * @param {number} x
 * @param {number} [y]
 * @param {number} [scale]
 * @returns {string}
 */function toTransformString(t, e, i) { let s = `translate3d(${t}px,${e || 0}px,0)`; i !== void 0 && (s += ` scale3d(${i},${i},1)`); return s }
/**
 * Apply width and height CSS properties to element
 *
 * @param {HTMLElement} el
 * @param {string | number} w
 * @param {string | number} h
 */function setWidthHeight(t, e, i) { t.style.width = typeof e === "number" ? `${e}px` : e; t.style.height = typeof i === "number" ? `${i}px` : i }
/** @typedef {LOAD_STATE[keyof LOAD_STATE]} LoadState */
/** @type {{ IDLE: 'idle'; LOADING: 'loading'; LOADED: 'loaded'; ERROR: 'error' }} */const t = { IDLE: "idle", LOADING: "loading", LOADED: "loaded", ERROR: "error" };
/**
 * Check if click or keydown event was dispatched
 * with a special key or via mouse wheel.
 *
 * @param {MouseEvent | KeyboardEvent} e
 * @returns {boolean}
 */function specialKeyUsed(t) { return "button" in t && t.button === 1 || t.ctrlKey || t.metaKey || t.altKey || t.shiftKey }
/**
 * Parse `gallery` or `children` options.
 *
 * @param {import('../photoswipe.js').ElementProvider} [option]
 * @param {string} [legacySelector]
 * @param {HTMLElement | Document} [parent]
 * @returns HTMLElement[]
 */function getElementsFromOption(t, e, i = document) {
  /** @type {HTMLElement[]} */
  let s = []; if (t instanceof Element) s = [t]; else if (t instanceof NodeList || Array.isArray(t)) s = Array.from(t); else { const n = typeof t === "string" ? t : e; n && (s = Array.from(i.querySelectorAll(n))) } return s
}
/**
 * Check if variable is PhotoSwipe class
 *
 * @param {any} fn
 * @returns {boolean}
 */function isPswpClass(t) { return typeof t === "function" && t.prototype && t.prototype.goTo }
/**
 * Check if browser is Safari
 *
 * @returns {boolean}
 */function isSafari() { return !!(navigator.vendor && navigator.vendor.match(/apple/i)) }
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
 */class PhotoSwipeEvent {
  /**
     * @param {T} type
     * @param {PhotoSwipeEventsMap[T]} [details]
     */
  constructor(t, e) { this.type = t; this.defaultPrevented = false; e && Object.assign(this, e) } preventDefault() { this.defaultPrevented = true }
} class Eventable {
  constructor() {
    /**
         * @type {{ [T in keyof PhotoSwipeEventsMap]?: ((event: AugmentedEvent<T>) => void)[] }}
         */
    this._listeners = {};
/**
     * @type {{ [T in keyof PhotoSwipeFiltersMap]?: Filter<T>[] }}
     */this._filters = {};
/** @type {PhotoSwipe | undefined} */this.pswp = void 0;
/** @type {PhotoSwipeOptions | undefined} */this.options = void 0
  }
/**
   * @template {keyof PhotoSwipeFiltersMap} T
   * @param {T} name
   * @param {PhotoSwipeFiltersMap[T]} fn
   * @param {number} priority
   */addFilter(t, e, i = 100) { var s, n, a; this._filters[t] || (this._filters[t] = []); (s = this._filters[t]) === null || s === void 0 || s.push({ fn: e, priority: i }); (n = this._filters[t]) === null || n === void 0 || n.sort(((t, e) => t.priority - e.priority)); (a = this.pswp) === null || a === void 0 || a.addFilter(t, e, i) }
/**
   * @template {keyof PhotoSwipeFiltersMap} T
   * @param {T} name
   * @param {PhotoSwipeFiltersMap[T]} fn
   */removeFilter(t, e) { this._filters[t] && (this._filters[t] = this._filters[t].filter((t => t.fn !== e))); this.pswp && this.pswp.removeFilter(t, e) }
/**
   * @template {keyof PhotoSwipeFiltersMap} T
   * @param {T} name
   * @param {Parameters<PhotoSwipeFiltersMap[T]>} args
   * @returns {Parameters<PhotoSwipeFiltersMap[T]>[0]}
   */applyFilters(t, ...e) { var i; (i = this._filters[t]) === null || i === void 0 || i.forEach((t => { e[0] = t.fn.apply(this, e) })); return e[0] }
/**
   * @template {keyof PhotoSwipeEventsMap} T
   * @param {T} name
   * @param {EventCallback<T>} fn
   */on(t, e) { var i, s; this._listeners[t] || (this._listeners[t] = []); (i = this._listeners[t]) === null || i === void 0 || i.push(e); (s = this.pswp) === null || s === void 0 || s.on(t, e) }
/**
   * @template {keyof PhotoSwipeEventsMap} T
   * @param {T} name
   * @param {EventCallback<T>} fn
   */off(t, e) { var i; this._listeners[t] && (this._listeners[t] = this._listeners[t].filter((t => e !== t))); (i = this.pswp) === null || i === void 0 || i.off(t, e) }
/**
   * @template {keyof PhotoSwipeEventsMap} T
   * @param {T} name
   * @param {PhotoSwipeEventsMap[T]} [details]
   * @returns {AugmentedEvent<T>}
   */dispatch(t, e) {
    var i; if (this.pswp) return this.pswp.dispatch(t, e); const s =
      /** @type {AugmentedEvent<T>} */
      new PhotoSwipeEvent(t, e); (i = this._listeners[t]) === null || i === void 0 || i.forEach((t => { t.call(this, s) })); return s
  }
} class Placeholder {
  /**
     * @param {string | false} imageSrc
     * @param {HTMLElement} container
     */
  constructor(t, e) {
    /** @type {HTMLImageElement | HTMLDivElement | null} */
    this.element = createElement("pswp__img pswp__img--placeholder", t ? "img" : "div", e); if (t) {
      const e =
        /** @type {HTMLImageElement} */
        this.element; e.decoding = "async"; e.alt = ""; e.src = t; e.setAttribute("role", "presentation")
    } this.element.setAttribute("aria-hidden", "true")
  }
/**
   * @param {number} width
   * @param {number} height
   */setDisplayedSize(t, e) { if (this.element) if (this.element.tagName === "IMG") { setWidthHeight(this.element, 250, "auto"); this.element.style.transformOrigin = "0 0"; this.element.style.transform = toTransformString(0, 0, t / 250) } else setWidthHeight(this.element, t, e) } destroy() { var t; (t = this.element) !== null && t !== void 0 && t.parentNode && this.element.remove(); this.element = null }
}
/** @typedef {import('./slide.js').default} Slide */
/** @typedef {import('./slide.js').SlideData} SlideData */
/** @typedef {import('../core/base.js').default} PhotoSwipeBase */
/** @typedef {import('../util/util.js').LoadState} LoadState */class Content {
  /**
     * @param {SlideData} itemData Slide data
     * @param {PhotoSwipeBase} instance PhotoSwipe or PhotoSwipeLightbox instance
     * @param {number} index
     */
  constructor(e, i, s) {
    this.instance = i; this.data = e; this.index = s;
/** @type {HTMLImageElement | HTMLDivElement | undefined} */this.element = void 0;
/** @type {Placeholder | undefined} */this.placeholder = void 0;
/** @type {Slide | undefined} */this.slide = void 0; this.displayedImageWidth = 0; this.displayedImageHeight = 0; this.width = Number(this.data.w) || Number(this.data.width) || 0; this.height = Number(this.data.h) || Number(this.data.height) || 0; this.isAttached = false; this.hasSlide = false; this.isDecoding = false;
/** @type {LoadState} */this.state = t.IDLE; this.data.type ? this.type = this.data.type : this.data.src ? this.type = "image" : this.type = "html"; this.instance.dispatch("contentInit", { content: this })
  } removePlaceholder() { this.placeholder && !this.keepPlaceholder() && setTimeout((() => { if (this.placeholder) { this.placeholder.destroy(); this.placeholder = void 0 } }), 1e3) }
/**
   * Preload content
   *
   * @param {boolean} isLazy
   * @param {boolean} [reload]
   */load(t, e) { if (this.slide && this.usePlaceholder()) if (this.placeholder) { const t = this.placeholder.element; t && !t.parentElement && this.slide.container.prepend(t) } else { const t = this.instance.applyFilters("placeholderSrc", !(!this.data.msrc || !this.slide.isFirstSlide) && this.data.msrc, this); this.placeholder = new Placeholder(t, this.slide.container) } if ((!this.element || e) && !this.instance.dispatch("contentLoad", { content: this, isLazy: t }).defaultPrevented) { if (this.isImageContent()) { this.element = createElement("pswp__img", "img"); this.displayedImageWidth && this.loadImage(t) } else { this.element = createElement("pswp__content", "div"); this.element.innerHTML = this.data.html || "" } e && this.slide && this.slide.updateContentSize(true) } }
/**
   * Preload image
   *
   * @param {boolean} isLazy
   */loadImage(e) {
    var i, s; if (!this.isImageContent() || !this.element || this.instance.dispatch("contentLoadImage", { content: this, isLazy: e }).defaultPrevented) return; const n =
      /** @type HTMLImageElement */
      this.element; this.updateSrcsetSizes(); this.data.srcset && (n.srcset = this.data.srcset); n.src = (i = this.data.src) !== null && i !== void 0 ? i : ""; n.alt = (s = this.data.alt) !== null && s !== void 0 ? s : ""; this.state = t.LOADING; if (n.complete) this.onLoaded(); else { n.onload = () => { this.onLoaded() }; n.onerror = () => { this.onError() } }
  }
/**
   * Assign slide to content
   *
   * @param {Slide} slide
   */setSlide(t) { this.slide = t; this.hasSlide = true; this.instance = t.pswp } onLoaded() { this.state = t.LOADED; if (this.slide && this.element) { this.instance.dispatch("loadComplete", { slide: this.slide, content: this }); if (this.slide.isActive && this.slide.heavyAppended && !this.element.parentNode) { this.append(); this.slide.updateContentSize(true) } this.state !== t.LOADED && this.state !== t.ERROR || this.removePlaceholder() } } onError() { this.state = t.ERROR; if (this.slide) { this.displayError(); this.instance.dispatch("loadComplete", { slide: this.slide, isError: true, content: this }); this.instance.dispatch("loadError", { slide: this.slide, content: this }) } }
/**
   * @returns {Boolean} If the content is currently loading
   */isLoading() { return this.instance.applyFilters("isContentLoading", this.state === t.LOADING, this) }
/**
   * @returns {Boolean} If the content is in error state
   */isError() { return this.state === t.ERROR }
/**
   * @returns {boolean} If the content is image
   */isImageContent() { return this.type === "image" }
/**
   * Update content size
   *
   * @param {Number} width
   * @param {Number} height
   */setDisplayedSize(t, e) { if (this.element) { this.placeholder && this.placeholder.setDisplayedSize(t, e); if (!this.instance.dispatch("contentResize", { content: this, width: t, height: e }).defaultPrevented) { setWidthHeight(this.element, t, e); if (this.isImageContent() && !this.isError()) { const i = !this.displayedImageWidth && t; this.displayedImageWidth = t; this.displayedImageHeight = e; i ? this.loadImage(false) : this.updateSrcsetSizes(); this.slide && this.instance.dispatch("imageSizeChange", { slide: this.slide, width: t, height: e, content: this }) } } } }
/**
   * @returns {boolean} If the content can be zoomed
   */isZoomable() { return this.instance.applyFilters("isContentZoomable", this.isImageContent() && this.state !== t.ERROR, this) } updateSrcsetSizes() {
    if (!this.isImageContent() || !this.element || !this.data.srcset) return; const t =
      /** @type HTMLImageElement */
      this.element; const e = this.instance.applyFilters("srcsetSizesWidth", this.displayedImageWidth, this); if (!t.dataset.largestUsedSize || e > parseInt(t.dataset.largestUsedSize, 10)) { t.sizes = e + "px"; t.dataset.largestUsedSize = String(e) }
  }
/**
   * @returns {boolean} If content should use a placeholder (from msrc by default)
   */usePlaceholder() { return this.instance.applyFilters("useContentPlaceholder", this.isImageContent(), this) } lazyLoad() { this.instance.dispatch("contentLazyLoad", { content: this }).defaultPrevented || this.load(true) }
/**
   * @returns {boolean} If placeholder should be kept after content is loaded
   */keepPlaceholder() { return this.instance.applyFilters("isKeepingPlaceholder", this.isLoading(), this) } destroy() { this.hasSlide = false; this.slide = void 0; if (!this.instance.dispatch("contentDestroy", { content: this }).defaultPrevented) { this.remove(); if (this.placeholder) { this.placeholder.destroy(); this.placeholder = void 0 } if (this.isImageContent() && this.element) { this.element.onload = null; this.element.onerror = null; this.element = void 0 } } } displayError() {
    if (this.slide) {
      var t, e; let i = createElement("pswp__error-msg", "div"); i.innerText = (t = (e = this.instance.options) === null || e === void 0 ? void 0 : e.errorMsg) !== null && t !== void 0 ? t : ""; i =
        /** @type {HTMLDivElement} */
        this.instance.applyFilters("contentErrorElement", i, this); this.element = createElement("pswp__content pswp__error-msg-container", "div"); this.element.appendChild(i); this.slide.container.innerText = ""; this.slide.container.appendChild(this.element); this.slide.updateContentSize(true); this.removePlaceholder()
    }
  } append() {
    if (this.isAttached || !this.element) return; this.isAttached = true; if (this.state === t.ERROR) { this.displayError(); return } if (this.instance.dispatch("contentAppend", { content: this }).defaultPrevented) return; const e = "decode" in this.element; if (this.isImageContent()) if (e && this.slide && (!this.slide.isActive || isSafari())) {
      this.isDecoding = true;
/** @type {HTMLImageElement} */this.element.decode().catch((() => { })).finally((() => { this.isDecoding = false; this.appendImage() }))
    } else this.appendImage(); else this.slide && !this.element.parentNode && this.slide.container.appendChild(this.element)
  } activate() { if (!this.instance.dispatch("contentActivate", { content: this }).defaultPrevented && this.slide) { this.isImageContent() && this.isDecoding && !isSafari() ? this.appendImage() : this.isError() && this.load(false, true); this.slide.holderElement && this.slide.holderElement.setAttribute("aria-hidden", "false") } } deactivate() { this.instance.dispatch("contentDeactivate", { content: this }); this.slide && this.slide.holderElement && this.slide.holderElement.setAttribute("aria-hidden", "true") } remove() { this.isAttached = false; if (!this.instance.dispatch("contentRemove", { content: this }).defaultPrevented) { this.element && this.element.parentNode && this.element.remove(); this.placeholder && this.placeholder.element && this.placeholder.element.remove() } } appendImage() { if (this.isAttached && !this.instance.dispatch("contentAppendImage", { content: this }).defaultPrevented) { this.slide && this.element && !this.element.parentNode && this.slide.container.appendChild(this.element); this.state !== t.LOADED && this.state !== t.ERROR || this.removePlaceholder() } }
}
/** @typedef {import('../photoswipe.js').PhotoSwipeOptions} PhotoSwipeOptions */
/** @typedef {import('../core/base.js').default} PhotoSwipeBase */
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {import('../slide/slide.js').SlideData} SlideData */
/**
 * @param {PhotoSwipeOptions} options
 * @param {PhotoSwipeBase} pswp
 * @returns {Point}
 */function getViewportSize(t, e) { if (t.getViewportSizeFn) { const i = t.getViewportSizeFn(t, e); if (i) return i } return { x: document.documentElement.clientWidth, y: window.innerHeight } }
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
 */function parsePaddingOption(t, e, i, s, n) { let a = 0; if (e.paddingFn) a = e.paddingFn(i, s, n)[t]; else if (e.padding) a = e.padding[t]; else { const i = "padding" + t[0].toUpperCase() + t.slice(1); e[i] && (a = e[i]) } return Number(a) || 0 }
/**
 * @param {PhotoSwipeOptions} options
 * @param {Point} viewportSize
 * @param {SlideData} itemData
 * @param {number} index
 * @returns {Point}
 */function getPanAreaSize(t, e, i, s) { return { x: e.x - parsePaddingOption("left", t, e, i, s) - parsePaddingOption("right", t, e, i, s), y: e.y - parsePaddingOption("top", t, e, i, s) - parsePaddingOption("bottom", t, e, i, s) } } const e = 4e3;
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/** @typedef {import('../photoswipe.js').PhotoSwipeOptions} PhotoSwipeOptions */
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {import('../slide/slide.js').SlideData} SlideData */
/** @typedef {'fit' | 'fill' | number | ((zoomLevelObject: ZoomLevel) => number)} ZoomLevelOption */class ZoomLevel {
  /**
     * @param {PhotoSwipeOptions} options PhotoSwipe options
     * @param {SlideData} itemData Slide data
     * @param {number} index Slide index
     * @param {PhotoSwipe} [pswp] PhotoSwipe instance, can be undefined if not initialized yet
     */
  constructor(t, e, i, s) {
    this.pswp = s; this.options = t; this.itemData = e; this.index = i;
/** @type { Point | null } */this.panAreaSize = null;
/** @type { Point | null } */this.elementSize = null; this.fit = 1; this.fill = 1; this.vFill = 1; this.initial = 1; this.secondary = 1; this.max = 1; this.min = 1
  }
/**
   * Calculate initial, secondary and maximum zoom level for the specified slide.
   *
   * It should be called when either image or viewport size changes.
   *
   * @param {number} maxWidth
   * @param {number} maxHeight
   * @param {Point} panAreaSize
   */update(t, e, i) {
    /** @type {Point} */
    const s = { x: t, y: e }; this.elementSize = s; this.panAreaSize = i; const n = i.x / s.x; const a = i.y / s.y; this.fit = Math.min(1, n < a ? n : a); this.fill = Math.min(1, n > a ? n : a); this.vFill = Math.min(1, a); this.initial = this._getInitial(); this.secondary = this._getSecondary(); this.max = Math.max(this.initial, this.secondary, this._getMax()); this.min = Math.min(this.fit, this.initial, this.secondary); this.pswp && this.pswp.dispatch("zoomLevelsUpdate", { zoomLevels: this, slideData: this.itemData })
  }
/**
   * Parses user-defined zoom option.
   *
   * @private
   * @param {'initial' | 'secondary' | 'max'} optionPrefix Zoom level option prefix (initial, secondary, max)
   * @returns { number | undefined }
   */_parseZoomLevelOption(t) {
    const e =
      /** @type {'initialZoomLevel' | 'secondaryZoomLevel' | 'maxZoomLevel'} */
      t + "ZoomLevel"; const i = this.options[e]; if (i) return typeof i === "function" ? i(this) : i === "fill" ? this.fill : i === "fit" ? this.fit : Number(i)
  } _getSecondary() { let t = this._parseZoomLevelOption("secondary"); if (t) return t; t = Math.min(1, this.fit * 3); this.elementSize && t * this.elementSize.x > e && (t = e / this.elementSize.x); return t } _getInitial() { return this._parseZoomLevelOption("initial") || this.fit } _getMax() { return this._parseZoomLevelOption("max") || Math.max(1, this.fit * 4) }
}
/**
 * Lazy-load an image
 * This function is used both by Lightbox and PhotoSwipe core,
 * thus it can be called before dialog is opened.
 *
 * @param {SlideData} itemData Data about the slide
 * @param {PhotoSwipeBase} instance PhotoSwipe or PhotoSwipeLightbox instance
 * @param {number} index
 * @returns {Content} Image that is being decoded or false.
 */function lazyLoadData(t, e, i) {
  const s = e.createContentFromData(t, i);
/** @type {ZoomLevel | undefined} */let n; const { options: a } = e; if (a) { n = new ZoomLevel(a, t, -1); let l; l = e.pswp ? e.pswp.viewportSize : getViewportSize(a, e); const o = getPanAreaSize(a, l, t, i); n.update(s.width, s.height, o) } s.lazyLoad(); n && s.setDisplayedSize(Math.ceil(s.width * n.initial), Math.ceil(s.height * n.initial)); return s
}
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
 */function lazyLoadSlide(t, e) { const i = e.getItemData(t); if (!e.dispatch("lazyLoadSlide", { index: t, itemData: i }).defaultPrevented) return lazyLoadData(i, e, t) }
/** @typedef {import("../photoswipe.js").default} PhotoSwipe */
/** @typedef {import("../slide/slide.js").SlideData} SlideData */class PhotoSwipeBase extends Eventable {
  /**
     * Get total number of slides
     *
     * @returns {number}
     */
  getNumItems() { var t; let e = 0; const i = (t = this.options) === null || t === void 0 ? void 0 : t.dataSource; if (i && "length" in i) e = i.length; else if (i && "gallery" in i) { i.items || (i.items = this._getGalleryDOMElements(i.gallery)); i.items && (e = i.items.length) } const s = this.dispatch("numItems", { dataSource: i, numItems: e }); return this.applyFilters("numItems", s.numItems, i) }
/**
   * @param {SlideData} slideData
   * @param {number} index
   * @returns {Content}
   */createContentFromData(t, e) { return new Content(t, this, e) }
/**
   * Get item data by index.
   *
   * "item data" should contain normalized information that PhotoSwipe needs to generate a slide.
   * For example, it may contain properties like
   * `src`, `srcset`, `w`, `h`, which will be used to generate a slide with image.
   *
   * @param {number} index
   * @returns {SlideData}
   */getItemData(t) {
    var e; const i = (e = this.options) === null || e === void 0 ? void 0 : e.dataSource;
/** @type {SlideData | HTMLElement} */let s = {}; if (Array.isArray(i)) s = i[t]; else if (i && "gallery" in i) { i.items || (i.items = this._getGalleryDOMElements(i.gallery)); s = i.items[t] } let n = s; n instanceof Element && (n = this._domElementToItemData(n)); const a = this.dispatch("itemData", { itemData: n || {}, index: t }); return this.applyFilters("itemData", a.itemData, t)
  }
/**
   * Get array of gallery DOM elements,
   * based on childSelector and gallery element.
   *
   * @param {HTMLElement} galleryElement
   * @returns {HTMLElement[]}
   */_getGalleryDOMElements(t) { var e, i; return (e = this.options) !== null && e !== void 0 && e.children || (i = this.options) !== null && i !== void 0 && i.childSelector ? getElementsFromOption(this.options.children, this.options.childSelector, t) || [] : [t] }
/**
   * Converts DOM element to item data object.
   *
   * @param {HTMLElement} element DOM element
   * @returns {SlideData}
   */_domElementToItemData(t) {
    /** @type {SlideData} */
    const e = { element: t }; const i =
      /** @type {HTMLAnchorElement} */
      t.tagName === "A" ? t : t.querySelector("a"); if (i) { e.src = i.dataset.pswpSrc || i.href; i.dataset.pswpSrcset && (e.srcset = i.dataset.pswpSrcset); e.width = i.dataset.pswpWidth ? parseInt(i.dataset.pswpWidth, 10) : 0; e.height = i.dataset.pswpHeight ? parseInt(i.dataset.pswpHeight, 10) : 0; e.w = e.width; e.h = e.height; i.dataset.pswpType && (e.type = i.dataset.pswpType); const n = t.querySelector("img"); if (n) { var s; e.msrc = n.currentSrc || n.src; e.alt = (s = n.getAttribute("alt")) !== null && s !== void 0 ? s : "" } (i.dataset.pswpCropped || i.dataset.cropped) && (e.thumbCropped = true) } return this.applyFilters("domItemData", e, t, i)
  }
/**
   * Lazy-load by slide data
   *
   * @param {SlideData} itemData Data about the slide
   * @param {number} index
   * @returns {Content} Image that is being decoded or false.
   */lazyLoadData(t, e) { return lazyLoadData(t, this, e) }
}
/**
 * @template T
 * @typedef {import('../types.js').Type<T>} Type<T>
 */
/** @typedef {import('../photoswipe.js').default} PhotoSwipe */
/** @typedef {import('../photoswipe.js').PhotoSwipeOptions} PhotoSwipeOptions */
/** @typedef {import('../photoswipe.js').DataSource} DataSource */
/** @typedef {import('../photoswipe.js').Point} Point */
/** @typedef {import('../slide/content.js').default} Content */
/** @typedef {import('../core/eventable.js').PhotoSwipeEventsMap} PhotoSwipeEventsMap */
/** @typedef {import('../core/eventable.js').PhotoSwipeFiltersMap} PhotoSwipeFiltersMap */
/**
 * @template {keyof PhotoSwipeEventsMap} T
 * @typedef {import('../core/eventable.js').EventCallback<T>} EventCallback<T>
 */class PhotoSwipeLightbox extends PhotoSwipeBase {
  /**
     * @param {PhotoSwipeOptions} [options]
     */
  constructor(t) {
    super();
/** @type {PhotoSwipeOptions} */this.options = t || {}; this._uid = 0; this.shouldOpen = false;
/**
     * @private
     * @type {Content | undefined}
     */this._preloadedContent = void 0; this.onThumbnailsClick = this.onThumbnailsClick.bind(this)
  } init() { getElementsFromOption(this.options.gallery, this.options.gallerySelector).forEach((t => { t.addEventListener("click", this.onThumbnailsClick, false) })) }
/**
   * @param {MouseEvent} e
   */onThumbnailsClick(t) {
    if (specialKeyUsed(t) || window.pswp) return;
/** @type {Point | null} */let e = { x: t.clientX, y: t.clientY }; e.x || e.y || (e = null); let i = this.getClickedIndex(t); i = this.applyFilters("clickedIndex", i, t, this);
/** @type {DataSource} */const s = {
      gallery:
        /** @type {HTMLElement} */
        t.currentTarget
    }; if (i >= 0) { t.preventDefault(); this.loadAndOpen(i, s, e) }
  }
/**
   * Get index of gallery item that was clicked.
   *
   * @param {MouseEvent} e click event
   * @returns {number}
   */getClickedIndex(t) {
    if (this.options.getClickedIndexFn) return this.options.getClickedIndexFn.call(this, t); const e =
      /** @type {HTMLElement} */
      t.target; const i = getElementsFromOption(this.options.children, this.options.childSelector,
        /** @type {HTMLElement} */
        t.currentTarget); const s = i.findIndex((t => t === e || t.contains(e))); return s !== -1 ? s : this.options.children || this.options.childSelector ? -1 : 0
  }
/**
   * Load and open PhotoSwipe
   *
   * @param {number} index
   * @param {DataSource} [dataSource]
   * @param {Point | null} [initialPoint]
   * @returns {boolean}
   */loadAndOpen(t, e, i) { if (window.pswp || !this.options) return false; if (!e && this.options.gallery && this.options.children) { const t = getElementsFromOption(this.options.gallery); t[0] && (e = { gallery: t[0] }) } this.options.index = t; this.options.initialPointerPos = i; this.shouldOpen = true; this.preload(t, e); return true }
/**
   * Load the main module and the slide content by index
   *
   * @param {number} index
   * @param {DataSource} [dataSource]
   */preload(t, e) {
    const { options: i } = this; e && (i.dataSource = e);
/** @type {Promise<Type<PhotoSwipe>>[]} */const s = []; const n = typeof i.pswpModule; if (isPswpClass(i.pswpModule)) s.push(Promise.resolve(
      /** @type {Type<PhotoSwipe>} */
      i.pswpModule)); else {
      if (n === "string") throw new Error("pswpModule as string is no longer supported"); if (n !== "function") throw new Error("pswpModule is not valid"); s.push(
        /** @type {() => Promise<Type<PhotoSwipe>>} */
        i.pswpModule())
    } typeof i.openPromise === "function" && s.push(i.openPromise()); i.preloadFirstSlide !== false && t >= 0 && (this._preloadedContent = lazyLoadSlide(t, this)); const a = ++this._uid; Promise.all(s).then((t => { if (this.shouldOpen) { const e = t[0]; this._openPhotoswipe(e, a) } }))
  }
/**
   * @private
   * @param {Type<PhotoSwipe> | { default: Type<PhotoSwipe> }} module
   * @param {number} uid
   */_openPhotoswipe(t, e) {
    if (e !== this._uid && this.shouldOpen) return; this.shouldOpen = false; if (window.pswp) return;
/**
     * Pass data to PhotoSwipe and open init
     *
     * @type {PhotoSwipe}
     */const i = typeof t === "object" ? new t.default(this.options) : new t(this.options); this.pswp = i; window.pswp = i;
/** @type {(keyof PhotoSwipeEventsMap)[]} */Object.keys(this._listeners).forEach((t => {
      var e; (e = this._listeners[t]) === null || e === void 0 || e.forEach((e => {
        i.on(t,
          /** @type {EventCallback<typeof name>} */
          e)
      }))
    }));
/** @type {(keyof PhotoSwipeFiltersMap)[]} */Object.keys(this._filters).forEach((t => { var e; (e = this._filters[t]) === null || e === void 0 || e.forEach((e => { i.addFilter(t, e.fn, e.priority) })) })); if (this._preloadedContent) { i.contentLoader.addToCache(this._preloadedContent); this._preloadedContent = void 0 } i.on("destroy", (() => { this.pswp = void 0; delete window.pswp })); i.init()
  } destroy() { var t; (t = this.pswp) === null || t === void 0 || t.destroy(); this.shouldOpen = false; this._listeners = {}; getElementsFromOption(this.options.gallery, this.options.gallerySelector).forEach((t => { t.removeEventListener("click", this.onThumbnailsClick, false) })) }
} export { PhotoSwipeLightbox as default };
//# sourceMappingURL=photoswipe-lightbox.esm.js.map
