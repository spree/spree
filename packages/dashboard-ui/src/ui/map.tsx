'use client'

import type { MarkerOptions, PopupOptions } from 'maplibre-gl'
import * as MapLibreGL from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

import type * as GeoJSON from 'geojson'
import { Loader2, Locate, Maximize, Minus, Plus, X } from 'lucide-react'
// `?worker&url` hands the file to the bundler, which emits it as its own chunk
// with the shared code it needs and gives back a same-origin URL.
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url'
import {
  createContext,
  forwardRef,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useId,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from 'react'
import { createPortal } from 'react-dom'
import { cn } from '../lib/utils'

// The worker ships in the package, so it is bundled and served from this
// origin. The registry's default fetches it from unpkg at runtime, which means
// executing third-party code the deploy never reviewed, a map that breaks when
// that CDN is unreachable, and a CSP that has to allow it.
if (typeof window !== 'undefined' && !MapLibreGL.getWorkerUrl()) {
  MapLibreGL.setWorkerUrl(workerUrl)
}

const defaultStyles = {
  dark: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
  light: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
}

// A tile-less, dependency-free style with a transparent background. Use it for
// data visualizations (choropleths, world arcs, dot maps) where you draw your
// own layers and don't need a street basemap. The easiest way to opt in is the
// `blank` prop:
//   <Map blank>...</Map>
// The transparent background lets the themed container show through.
const blankMapStyle: MapLibreGL.StyleSpecification = {
  version: 8,
  sources: {},
  layers: [
    {
      id: 'background',
      type: 'background',
      paint: { 'background-color': 'rgba(0, 0, 0, 0)' },
    },
  ],
}

// Prevent equivalent inline style objects from triggering a full map style reload.
function useStableValue<T>(value: T): T {
  const key = useMemo(() => JSON.stringify(value) ?? '', [value])
  // eslint-disable-next-line react-hooks/exhaustive-deps
  return useMemo(() => value, [key])
}

function mergeHoverPaint<T extends Record<string, unknown>>(
  paint: T,
  hoverPaint: T | undefined,
): T {
  if (!hoverPaint) return paint
  const merged: Record<string, unknown> = { ...paint }
  for (const [key, hoverValue] of Object.entries(hoverPaint)) {
    if (hoverValue === undefined) continue
    const baseValue = merged[key]
    merged[key] =
      baseValue === undefined
        ? hoverValue
        : ['case', ['boolean', ['feature-state', 'hover'], false], hoverValue, baseValue]
  }
  return merged as T
}

type Theme = 'light' | 'dark'

// Check the document for an explicit theme (works with next-themes, etc.).
// Covers both `attribute="class"` (the default) and `attribute="data-theme"`.
function getDocumentTheme(): Theme | null {
  if (typeof document === 'undefined') return null
  const root = document.documentElement
  if (root.classList.contains('dark')) return 'dark'
  if (root.classList.contains('light')) return 'light'
  const dataTheme = root.dataset.theme
  if (dataTheme === 'dark' || dataTheme === 'light') return dataTheme
  return null
}

// Get system preference
function getSystemTheme(): Theme {
  if (typeof window === 'undefined') return 'light'
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

function useResolvedTheme(themeProp?: 'light' | 'dark'): Theme {
  const [detectedTheme, setDetectedTheme] = useState<Theme>(
    () => getDocumentTheme() ?? getSystemTheme(),
  )

  useEffect(() => {
    if (themeProp) return // Skip detection if theme is provided via prop

    // Watch for document theme changes (e.g., next-themes toggling the class
    // or the data-theme attribute).
    const observer = new MutationObserver(() => {
      const docTheme = getDocumentTheme()
      if (docTheme) {
        setDetectedTheme(docTheme)
      }
    })
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class', 'data-theme'],
    })

    // Also watch for system preference changes
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    const handleSystemChange = (e: MediaQueryListEvent) => {
      // Only use system preference if no document class is set
      if (!getDocumentTheme()) {
        setDetectedTheme(e.matches ? 'dark' : 'light')
      }
    }
    mediaQuery.addEventListener('change', handleSystemChange)

    return () => {
      observer.disconnect()
      mediaQuery.removeEventListener('change', handleSystemChange)
    }
  }, [themeProp])

  return themeProp ?? detectedTheme
}

type MapContextValue = {
  map: MapLibreGL.Map | null
  isLoaded: boolean
  resolvedTheme: Theme
}

const MapContext = createContext<MapContextValue | null>(null)

function useMap() {
  const context = useContext(MapContext)
  if (!context) {
    throw new Error('useMap must be used within a Map component')
  }
  return context
}

/** Map viewport state */
type MapViewport = {
  /** Center coordinates [longitude, latitude] */
  center: [number, number]
  /** Zoom level */
  zoom: number
  /** Bearing (rotation) in degrees */
  bearing: number
  /** Pitch (tilt) in degrees */
  pitch: number
}

type MapStyleOption = string | MapLibreGL.StyleSpecification

type MapRef = MapLibreGL.Map

type MapProps = {
  children?: ReactNode
  /** Additional CSS classes for the map container */
  className?: string
  /**
   * Theme for the map. If not provided, automatically detects system preference.
   * Pass your theme value here.
   */
  theme?: Theme
  /** Custom map styles for light and dark themes. Overrides the default Carto styles. */
  styles?: {
    light?: MapStyleOption
    dark?: MapStyleOption
  }
  /**
   * Use a transparent, tile-less basemap instead of the default Carto street
   * basemap — a blank canvas. Used alone it renders nothing; add your own
   * layers on top (`<MapGeoJSON>`, `<MapArc>`, markers, etc.). Ideal for data
   * visualizations (choropleths, arcs, dot maps).
   * Ignored when an explicit `styles` prop is provided.
   */
  blank?: boolean
  /** Map projection type. Use `{ type: "globe" }` for 3D globe view. */
  projection?: MapLibreGL.ProjectionSpecification
  /**
   * Controlled viewport. When provided with onViewportChange,
   * the map becomes controlled and viewport is driven by this prop.
   */
  viewport?: Partial<MapViewport>
  /**
   * Callback fired continuously as the viewport changes (pan, zoom, rotate, pitch).
   * Can be used standalone to observe changes, or with `viewport` prop
   * to enable controlled mode where the map viewport is driven by your state.
   */
  onViewportChange?: (viewport: MapViewport) => void
  /** Show a loading indicator on the map */
  loading?: boolean
} & Omit<MapLibreGL.MapOptions, 'container' | 'style'>

function DefaultLoader() {
  return (
    <div className="bg-background/50 absolute inset-0 z-10 flex items-center justify-center backdrop-blur-xs">
      <div className="flex gap-1">
        <span className="bg-muted-foreground/60 size-1.5 animate-pulse rounded-full" />
        <span className="bg-muted-foreground/60 size-1.5 animate-pulse rounded-full [animation-delay:150ms]" />
        <span className="bg-muted-foreground/60 size-1.5 animate-pulse rounded-full [animation-delay:300ms]" />
      </div>
    </div>
  )
}

function getViewport(map: MapLibreGL.Map): MapViewport {
  const center = map.getCenter()
  return {
    center: [center.lng, center.lat],
    zoom: map.getZoom(),
    bearing: map.getBearing(),
    pitch: map.getPitch(),
  }
}

const Map = forwardRef<MapRef, MapProps>(function Map(
  {
    children,
    className,
    theme: themeProp,
    styles,
    blank = false,
    projection,
    viewport,
    onViewportChange,
    loading = false,
    ...props
  },
  ref,
) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [mapInstance, setMapInstance] = useState<MapLibreGL.Map | null>(null)
  const [isLoaded, setIsLoaded] = useState(false)
  const [isStyleLoaded, setIsStyleLoaded] = useState(false)
  const [pendingStyle, setPendingStyle] = useState<MapStyleOption | null>(null)
  const currentStyleRef = useRef<MapStyleOption | null>(null)
  const styleSwapInFlightRef = useRef(false)
  const internalUpdateRef = useRef(false)
  const resolvedTheme = useResolvedTheme(themeProp)

  const isControlled = viewport !== undefined && onViewportChange !== undefined

  const onViewportChangeRef = useRef(onViewportChange)
  onViewportChangeRef.current = onViewportChange

  const stableStyles = useStableValue(styles)

  const mapStyles = useMemo(() => {
    // Explicit styles win. Otherwise `blank` opts into the transparent
    // tile-less basemap; with neither, fall back to the Carto defaults.
    if (stableStyles) {
      return {
        dark: stableStyles.dark ?? defaultStyles.dark,
        light: stableStyles.light ?? defaultStyles.light,
      }
    }
    if (blank) {
      return { dark: blankMapStyle, light: blankMapStyle }
    }
    return defaultStyles
  }, [stableStyles, blank])

  // Expose the map instance to the parent component
  useImperativeHandle(ref, () => mapInstance as MapLibreGL.Map, [mapInstance])

  // Initialize the map
  useEffect(() => {
    if (!containerRef.current) return

    const initialStyle = resolvedTheme === 'dark' ? mapStyles.dark : mapStyles.light
    currentStyleRef.current = initialStyle

    const map = new MapLibreGL.Map({
      container: containerRef.current,
      style: initialStyle,
      renderWorldCopies: false,
      attributionControl: {
        compact: true,
      },
      ...props,
      ...viewport,
    })

    const styleLoadHandler = () => {
      styleSwapInFlightRef.current = false
      setIsStyleLoaded(true)
    }
    const loadHandler = () => setIsLoaded(true)

    // Viewport change handler - skip if triggered by internal update
    const handleMove = () => {
      if (internalUpdateRef.current) return
      onViewportChangeRef.current?.(getViewport(map))
    }

    map.on('load', loadHandler)
    map.on('style.load', styleLoadHandler)
    map.on('move', handleMove)
    setMapInstance(map)

    return () => {
      map.off('load', loadHandler)
      map.off('style.load', styleLoadHandler)
      map.off('move', handleMove)
      map.remove()
      setIsLoaded(false)
      setIsStyleLoaded(false)
      setMapInstance(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Sync controlled viewport to map
  useEffect(() => {
    if (!mapInstance || !isControlled || !viewport) return
    if (mapInstance.isMoving()) return

    const current = getViewport(mapInstance)
    const next = {
      center: viewport.center ?? current.center,
      zoom: viewport.zoom ?? current.zoom,
      bearing: viewport.bearing ?? current.bearing,
      pitch: viewport.pitch ?? current.pitch,
    }

    if (
      next.center[0] === current.center[0] &&
      next.center[1] === current.center[1] &&
      next.zoom === current.zoom &&
      next.bearing === current.bearing &&
      next.pitch === current.pitch
    ) {
      return
    }

    internalUpdateRef.current = true
    mapInstance.jumpTo(next)
    internalUpdateRef.current = false
  }, [mapInstance, isControlled, viewport])

  // Handle style change: close the gate (so layer children tear down and
  // re-add on the incoming style) - the swap itself is staged to the effect below.
  useEffect(() => {
    if (!mapInstance || !resolvedTheme) return

    const newStyle = resolvedTheme === 'dark' ? mapStyles.dark : mapStyles.light

    if (currentStyleRef.current === newStyle) return

    currentStyleRef.current = newStyle
    setIsStyleLoaded(false)
    setPendingStyle(newStyle)
  }, [mapInstance, resolvedTheme, mapStyles])

  useEffect(() => {
    if (!mapInstance || !pendingStyle) return

    setPendingStyle(null)
    styleSwapInFlightRef.current = true
    // Full reload (no diff) so `style.load` fires deterministically. A
    // successful diff would never fire it, leaving isStyleLoaded stuck false.
    mapInstance.setStyle(pendingStyle, { diff: false })
  }, [mapInstance, pendingStyle])

  // Sync projection when the prop changes after mount.
  useEffect(() => {
    if (!mapInstance || !isStyleLoaded || !projection) return
    if (styleSwapInFlightRef.current) return
    mapInstance.setProjection(projection)
  }, [mapInstance, isStyleLoaded, projection])

  const contextValue = useMemo(
    () => ({
      map: mapInstance,
      isLoaded: isLoaded && isStyleLoaded,
      resolvedTheme,
    }),
    [mapInstance, isLoaded, isStyleLoaded, resolvedTheme],
  )

  return (
    <MapContext.Provider value={contextValue}>
      <div ref={containerRef} className={cn('relative h-full w-full', className)}>
        {(!isLoaded || loading) && <DefaultLoader />}
        {/* SSR-safe: children render only when map is loaded on client */}
        {mapInstance && children}
      </div>
    </MapContext.Provider>
  )
})

type MarkerContextValue = {
  marker: MapLibreGL.Marker
  map: MapLibreGL.Map | null
}

const MarkerContext = createContext<MarkerContextValue | null>(null)

function useMarkerContext() {
  const context = useContext(MarkerContext)
  if (!context) {
    throw new Error('Marker components must be used within MapMarker')
  }
  return context
}

type MapMarkerProps = {
  /** Longitude coordinate for marker position */
  longitude: number
  /** Latitude coordinate for marker position */
  latitude: number
  /** Marker subcomponents (MarkerContent, MarkerPopup, MarkerTooltip, MarkerLabel) */
  children: ReactNode
  /** Callback when marker is clicked */
  onClick?: (e: MouseEvent) => void
  /** Callback when mouse enters marker */
  onMouseEnter?: (e: MouseEvent) => void
  /** Callback when mouse leaves marker */
  onMouseLeave?: (e: MouseEvent) => void
  /** Callback when marker drag starts (requires draggable: true) */
  onDragStart?: (lngLat: { lng: number; lat: number }) => void
  /** Callback during marker drag (requires draggable: true) */
  onDrag?: (lngLat: { lng: number; lat: number }) => void
  /** Callback when marker drag ends (requires draggable: true) */
  onDragEnd?: (lngLat: { lng: number; lat: number }) => void
} & Omit<MarkerOptions, 'element'>

function MapMarker({
  longitude,
  latitude,
  children,
  onClick,
  onMouseEnter,
  onMouseLeave,
  onDragStart,
  onDrag,
  onDragEnd,
  draggable = false,
  ...markerOptions
}: MapMarkerProps) {
  const { map } = useMap()

  const callbacksRef = useRef({
    onClick,
    onMouseEnter,
    onMouseLeave,
    onDragStart,
    onDrag,
    onDragEnd,
  })
  callbacksRef.current = {
    onClick,
    onMouseEnter,
    onMouseLeave,
    onDragStart,
    onDrag,
    onDragEnd,
  }

  const marker = useMemo(() => {
    const markerInstance = new MapLibreGL.Marker({
      ...markerOptions,
      element: document.createElement('div'),
      draggable,
    }).setLngLat([longitude, latitude])

    const handleClick = (e: MouseEvent) => callbacksRef.current.onClick?.(e)
    const handleMouseEnter = (e: MouseEvent) => callbacksRef.current.onMouseEnter?.(e)
    const handleMouseLeave = (e: MouseEvent) => callbacksRef.current.onMouseLeave?.(e)

    markerInstance.getElement()?.addEventListener('click', handleClick)
    markerInstance.getElement()?.addEventListener('mouseenter', handleMouseEnter)
    markerInstance.getElement()?.addEventListener('mouseleave', handleMouseLeave)

    const handleDragStart = () => {
      const lngLat = markerInstance.getLngLat()
      callbacksRef.current.onDragStart?.({ lng: lngLat.lng, lat: lngLat.lat })
    }
    const handleDrag = () => {
      const lngLat = markerInstance.getLngLat()
      callbacksRef.current.onDrag?.({ lng: lngLat.lng, lat: lngLat.lat })
    }
    const handleDragEnd = () => {
      const lngLat = markerInstance.getLngLat()
      callbacksRef.current.onDragEnd?.({ lng: lngLat.lng, lat: lngLat.lat })
    }

    markerInstance.on('dragstart', handleDragStart)
    markerInstance.on('drag', handleDrag)
    markerInstance.on('dragend', handleDragEnd)

    return markerInstance

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!map) return

    marker.addTo(map)

    return () => {
      marker.remove()
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map])

  const { offset, rotation, rotationAlignment, pitchAlignment } = markerOptions

  useEffect(() => {
    const current = marker.getLngLat()
    if (current.lng !== longitude || current.lat !== latitude) {
      marker.setLngLat([longitude, latitude])
    }

    if (marker.isDraggable() !== draggable) {
      marker.setDraggable(draggable)
    }

    const currentOffset = marker.getOffset()
    const newOffset = offset ?? [0, 0]
    const [newOffsetX, newOffsetY] = Array.isArray(newOffset)
      ? newOffset
      : [newOffset.x, newOffset.y]
    if (currentOffset.x !== newOffsetX || currentOffset.y !== newOffsetY) {
      marker.setOffset(newOffset)
    }

    if (marker.getRotation() !== (rotation ?? 0)) {
      marker.setRotation(rotation ?? 0)
    }
    if (marker.getRotationAlignment() !== (rotationAlignment ?? 'auto')) {
      marker.setRotationAlignment(rotationAlignment ?? 'auto')
    }
    if (marker.getPitchAlignment() !== (pitchAlignment ?? 'auto')) {
      marker.setPitchAlignment(pitchAlignment ?? 'auto')
    }
  }, [marker, longitude, latitude, draggable, offset, rotation, rotationAlignment, pitchAlignment])

  return <MarkerContext.Provider value={{ marker, map }}>{children}</MarkerContext.Provider>
}

type MarkerContentProps = {
  /** Custom marker content. Defaults to a blue dot if not provided */
  children?: ReactNode
  /** Additional CSS classes for the marker container */
  className?: string
}

function MarkerContent({ children, className }: MarkerContentProps) {
  const { marker } = useMarkerContext()

  return createPortal(
    <div className={cn('relative cursor-pointer', className)}>
      {children || <DefaultMarkerIcon />}
    </div>,
    marker.getElement(),
  )
}

function DefaultMarkerIcon() {
  return (
    <div className="relative h-4 w-4 rounded-full border-2 border-white bg-blue-500 shadow-lg" />
  )
}

function PopupCloseButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label="Close popup"
      className="focus-visible:ring-ring hover:bg-muted text-foreground absolute top-1 right-1 z-10 inline-flex size-5 cursor-pointer items-center justify-center rounded-sm transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-inset"
    >
      <X className="size-3.5" />
    </button>
  )
}

type MarkerPopupProps = {
  /** Popup content */
  children: ReactNode
  /** Additional CSS classes for the popup container */
  className?: string
  /** Show a close button in the popup (default: false) */
  closeButton?: boolean
} & Omit<PopupOptions, 'className' | 'closeButton'>

function MarkerPopup({
  children,
  className,
  closeButton = false,
  ...popupOptions
}: MarkerPopupProps) {
  const { marker, map } = useMarkerContext()
  const container = useMemo(() => document.createElement('div'), [])
  const { offset, maxWidth } = popupOptions

  const popup = useMemo(() => {
    const popupInstance = new MapLibreGL.Popup({
      offset: 16,
      ...popupOptions,
      closeButton: false,
    })
      .setMaxWidth('none')
      .setDOMContent(container)

    return popupInstance
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!map) return

    popup.setDOMContent(container)
    marker.setPopup(popup)

    return () => {
      marker.setPopup(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map])

  // Sync popup options when they change.
  useEffect(() => {
    popup.setOffset(offset ?? 16)
    if (maxWidth) {
      popup.setMaxWidth(maxWidth)
    }
  }, [popup, offset, maxWidth])

  const handleClose = () => popup.remove()

  return createPortal(
    <div
      className={cn(
        'bg-popover text-popover-foreground relative max-w-62 rounded-md border p-3 shadow-md',
        'animate-in fade-in-0 zoom-in-95 duration-200 ease-out',
        className,
      )}
    >
      {closeButton && <PopupCloseButton onClick={handleClose} />}
      {children}
    </div>,
    container,
  )
}

type MarkerTooltipProps = {
  /** Tooltip content */
  children: ReactNode
  /** Additional CSS classes for the tooltip container */
  className?: string
} & Omit<PopupOptions, 'className' | 'closeButton' | 'closeOnClick'>

function MarkerTooltip({ children, className, ...popupOptions }: MarkerTooltipProps) {
  const { marker, map } = useMarkerContext()
  const container = useMemo(() => document.createElement('div'), [])
  const { offset, maxWidth } = popupOptions

  const tooltip = useMemo(() => {
    const tooltipInstance = new MapLibreGL.Popup({
      offset: 16,
      ...popupOptions,
      closeOnClick: true,
      closeButton: false,
    }).setMaxWidth('none')

    return tooltipInstance
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!map) return

    tooltip.setDOMContent(container)

    const handleMouseEnter = () => {
      tooltip.setLngLat(marker.getLngLat()).addTo(map)
    }
    const handleMouseLeave = () => tooltip.remove()

    marker.getElement()?.addEventListener('mouseenter', handleMouseEnter)
    marker.getElement()?.addEventListener('mouseleave', handleMouseLeave)

    return () => {
      marker.getElement()?.removeEventListener('mouseenter', handleMouseEnter)
      marker.getElement()?.removeEventListener('mouseleave', handleMouseLeave)
      tooltip.remove()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map])

  // Sync tooltip options when they change.
  useEffect(() => {
    tooltip.setOffset(offset ?? 16)
    if (maxWidth) {
      tooltip.setMaxWidth(maxWidth)
    }
  }, [tooltip, offset, maxWidth])

  return createPortal(
    <div
      className={cn(
        'bg-foreground text-background pointer-events-none rounded-md px-2 py-1 text-xs text-balance shadow-md',
        'animate-in fade-in-0 zoom-in-95 duration-200 ease-out',
        className,
      )}
    >
      {children}
    </div>,
    container,
  )
}

type MarkerLabelProps = {
  /** Label text content */
  children: ReactNode
  /** Additional CSS classes for the label */
  className?: string
  /** Position of the label relative to the marker (default: "top") */
  position?: 'top' | 'bottom'
}

function MarkerLabel({ children, className, position = 'top' }: MarkerLabelProps) {
  const positionClasses = {
    top: 'bottom-full mb-1',
    bottom: 'top-full mt-1',
  }

  return (
    <div
      className={cn(
        'absolute left-1/2 -translate-x-1/2 whitespace-nowrap',
        'text-foreground text-[10px] font-medium',
        positionClasses[position],
        className,
      )}
    >
      {children}
    </div>
  )
}

type MapControlsProps = {
  /** Position of the controls on the map (default: "bottom-right") */
  position?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
  /** Show zoom in/out buttons (default: true) */
  showZoom?: boolean
  /** Show compass button to reset bearing (default: false) */
  showCompass?: boolean
  /** Show locate button to find user's location (default: false) */
  showLocate?: boolean
  /** Show fullscreen toggle button (default: false) */
  showFullscreen?: boolean
  /** Additional CSS classes for the controls container */
  className?: string
  /** Callback with user coordinates when located */
  onLocate?: (coords: { longitude: number; latitude: number }) => void
}

const positionClasses = {
  'top-left': 'top-2 left-2',
  'top-right': 'top-2 right-2',
  'bottom-left': 'bottom-2 left-2',
  'bottom-right': 'bottom-10 right-2',
}

function ControlGroup({ children }: { children: React.ReactNode }) {
  return (
    <div className="border-border bg-background [&>button:not(:last-child)]:border-border flex flex-col overflow-hidden rounded-md border shadow-sm [&>button:not(:last-child)]:border-b">
      {children}
    </div>
  )
}

function ControlButton({
  onClick,
  label,
  children,
  disabled = false,
}: {
  onClick: () => void
  label: string
  children: React.ReactNode
  disabled?: boolean
}) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      type="button"
      className={cn(
        'flex size-8 items-center justify-center transition-colors',
        'first:rounded-t-md last:rounded-b-md',
        'hover:bg-accent dark:hover:bg-accent/40',
        'focus-visible:ring-ring focus-visible:ring-2 focus-visible:outline-none focus-visible:ring-inset',
        'disabled:pointer-events-none disabled:opacity-50',
      )}
      disabled={disabled}
    >
      {children}
    </button>
  )
}

function MapControls({
  position = 'bottom-right',
  showZoom = true,
  showCompass = false,
  showLocate = false,
  showFullscreen = false,
  className,
  onLocate,
}: MapControlsProps) {
  const { map } = useMap()
  const [waitingForLocation, setWaitingForLocation] = useState(false)

  const handleZoomIn = useCallback(() => {
    map?.zoomTo(map.getZoom() + 1, { duration: 300 })
  }, [map])

  const handleZoomOut = useCallback(() => {
    map?.zoomTo(map.getZoom() - 1, { duration: 300 })
  }, [map])

  const handleResetBearing = useCallback(() => {
    map?.resetNorthPitch({ duration: 300 })
  }, [map])

  const handleLocate = useCallback(() => {
    if (!('geolocation' in navigator)) return
    setWaitingForLocation(true)
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const coords = {
          longitude: pos.coords.longitude,
          latitude: pos.coords.latitude,
        }
        map?.flyTo({
          center: [coords.longitude, coords.latitude],
          zoom: 14,
          duration: 1500,
        })
        onLocate?.(coords)
        setWaitingForLocation(false)
      },
      (error) => {
        console.error('Error getting location:', error)
        setWaitingForLocation(false)
      },
      // Without a timeout the spec default is Infinity: a dismissed permission
      // prompt would leave the button disabled forever.
      { timeout: 10000 },
    )
  }, [map, onLocate])

  const handleFullscreen = useCallback(() => {
    const container = map?.getContainer()
    if (!container) return
    if (document.fullscreenElement) {
      document.exitFullscreen()
    } else {
      container.requestFullscreen()
    }
  }, [map])

  return (
    <div
      className={cn('absolute z-10 flex flex-col gap-1.5', positionClasses[position], className)}
    >
      {showZoom && (
        <ControlGroup>
          <ControlButton onClick={handleZoomIn} label="Zoom in">
            <Plus className="size-4" />
          </ControlButton>
          <ControlButton onClick={handleZoomOut} label="Zoom out">
            <Minus className="size-4" />
          </ControlButton>
        </ControlGroup>
      )}
      {showCompass && (
        <ControlGroup>
          <CompassButton onClick={handleResetBearing} />
        </ControlGroup>
      )}
      {showLocate && (
        <ControlGroup>
          <ControlButton
            onClick={handleLocate}
            label="Find my location"
            disabled={waitingForLocation}
          >
            {waitingForLocation ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Locate className="size-4" />
            )}
          </ControlButton>
        </ControlGroup>
      )}
      {showFullscreen && (
        <ControlGroup>
          <ControlButton onClick={handleFullscreen} label="Toggle fullscreen">
            <Maximize className="size-4" />
          </ControlButton>
        </ControlGroup>
      )}
    </div>
  )
}

function CompassButton({ onClick }: { onClick: () => void }) {
  const { map } = useMap()
  const compassRef = useRef<SVGSVGElement>(null)

  useEffect(() => {
    if (!map || !compassRef.current) return

    const compass = compassRef.current

    const updateRotation = () => {
      const bearing = map.getBearing()
      const pitch = map.getPitch()
      compass.style.transform = `rotateX(${pitch}deg) rotateZ(${-bearing}deg)`
    }

    map.on('rotate', updateRotation)
    map.on('pitch', updateRotation)
    updateRotation()

    return () => {
      map.off('rotate', updateRotation)
      map.off('pitch', updateRotation)
    }
  }, [map])

  return (
    <ControlButton onClick={onClick} label="Reset bearing to north">
      <svg
        ref={compassRef}
        viewBox="0 0 24 24"
        className="size-5"
        style={{ transformStyle: 'preserve-3d' }}
      >
        <path d="M12 2L16 12H12V2Z" className="fill-red-500" />
        <path d="M12 2L8 12H12V2Z" className="fill-red-300" />
        <path d="M12 22L16 12H12V22Z" className="fill-muted-foreground/60" />
        <path d="M12 22L8 12H12V22Z" className="fill-muted-foreground/30" />
      </svg>
    </ControlButton>
  )
}

type MapPopupProps = {
  /** Longitude coordinate for popup position */
  longitude: number
  /** Latitude coordinate for popup position */
  latitude: number
  /** Callback when popup is closed */
  onClose?: () => void
  /** Popup content */
  children: ReactNode
  /** Additional CSS classes for the popup container */
  className?: string
  /** Show a close button in the popup (default: false) */
  closeButton?: boolean
} & Omit<PopupOptions, 'className' | 'closeButton'>

function MapPopup({
  longitude,
  latitude,
  onClose,
  children,
  className,
  closeButton = false,
  ...popupOptions
}: MapPopupProps) {
  const { map } = useMap()
  const onCloseRef = useRef(onClose)
  onCloseRef.current = onClose
  const container = useMemo(() => document.createElement('div'), [])
  const { offset, maxWidth } = popupOptions

  const popup = useMemo(() => {
    const popupInstance = new MapLibreGL.Popup({
      offset: 16,
      ...popupOptions,
      closeButton: false,
    })
      .setMaxWidth('none')
      .setLngLat([longitude, latitude])

    return popupInstance
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!map) return

    const onCloseProp = () => onCloseRef.current?.()

    popup.on('close', onCloseProp)

    popup.setDOMContent(container)
    popup.addTo(map)

    return () => {
      popup.off('close', onCloseProp)
      if (popup.isOpen()) {
        popup.remove()
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map])

  // Sync popup position and options when they change.
  useEffect(() => {
    const current = popup.getLngLat()
    if (!current || current.lng !== longitude || current.lat !== latitude) {
      popup.setLngLat([longitude, latitude])
    }
    popup.setOffset(offset ?? 16)
    if (maxWidth) {
      popup.setMaxWidth(maxWidth)
    }
  }, [popup, longitude, latitude, offset, maxWidth])

  const handleClose = () => {
    popup.remove()
  }

  return createPortal(
    <div
      className={cn(
        'bg-popover text-popover-foreground relative max-w-62 rounded-md border p-3 shadow-md',
        'animate-in fade-in-0 zoom-in-95 duration-200 ease-out',
        className,
      )}
    >
      {closeButton && <PopupCloseButton onClick={handleClose} />}
      {children}
    </div>,
    container,
  )
}

type MapRouteProps = {
  /** Optional unique identifier for the route layer */
  id?: string
  /** Array of [longitude, latitude] coordinate pairs defining the route */
  coordinates: [number, number][]
  /** Line color as CSS color value (default: "#4285F4") */
  color?: string
  /** Line width in pixels (default: 3) */
  width?: number
  /** Line opacity from 0 to 1 (default: 0.8) */
  opacity?: number
  /** Dash pattern [dash length, gap length] for dashed lines */
  dashArray?: [number, number]
  /** Callback when the route line is clicked */
  onClick?: () => void
  /** Callback when mouse enters the route line */
  onMouseEnter?: () => void
  /** Callback when mouse leaves the route line */
  onMouseLeave?: () => void
  /** Whether the route is interactive - shows pointer cursor on hover (default: true) */
  interactive?: boolean
}

function MapRoute({
  id: propId,
  coordinates,
  color = '#4285F4',
  width = 3,
  opacity = 0.8,
  dashArray,
  onClick,
  onMouseEnter,
  onMouseLeave,
  interactive = true,
}: MapRouteProps) {
  const { map, isLoaded } = useMap()
  const autoId = useId()
  const id = propId ?? autoId
  const sourceId = `route-source-${id}`
  const layerId = `route-layer-${id}`

  // Add source and layer on mount
  useEffect(() => {
    if (!isLoaded || !map) return

    map.addSource(sourceId, {
      type: 'geojson',
      data: {
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: [] },
      },
    })

    map.addLayer({
      id: layerId,
      type: 'line',
      source: sourceId,
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: {
        'line-color': color,
        'line-width': width,
        'line-opacity': opacity,
        ...(dashArray && { 'line-dasharray': dashArray }),
      },
    })

    return () => {
      try {
        if (map.getLayer(layerId)) map.removeLayer(layerId)
        if (map.getSource(sourceId)) map.removeSource(sourceId)
      } catch {
        // ignore
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoaded, map])

  // When coordinates change, update the source data
  useEffect(() => {
    if (!isLoaded || !map || coordinates.length < 2) return

    const source = map.getSource(sourceId) as MapLibreGL.GeoJSONSource
    if (source) {
      source.setData({
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates },
      })
    }
  }, [isLoaded, map, coordinates, sourceId])

  useEffect(() => {
    if (!isLoaded || !map || !map.getLayer(layerId)) return

    map.setPaintProperty(layerId, 'line-color', color)
    map.setPaintProperty(layerId, 'line-width', width)
    map.setPaintProperty(layerId, 'line-opacity', opacity)
    map.setPaintProperty(layerId, 'line-dasharray', dashArray)
  }, [isLoaded, map, layerId, color, width, opacity, dashArray])

  // Handle click and hover events
  useEffect(() => {
    if (!isLoaded || !map || !interactive) return

    const handleClick = () => {
      onClick?.()
    }
    const handleMouseEnter = () => {
      map.getCanvas().style.cursor = 'pointer'
      onMouseEnter?.()
    }
    const handleMouseLeave = () => {
      map.getCanvas().style.cursor = ''
      onMouseLeave?.()
    }

    map.on('click', layerId, handleClick)
    map.on('mouseenter', layerId, handleMouseEnter)
    map.on('mouseleave', layerId, handleMouseLeave)

    return () => {
      map.off('click', layerId, handleClick)
      map.off('mouseenter', layerId, handleMouseEnter)
      map.off('mouseleave', layerId, handleMouseLeave)
    }
  }, [isLoaded, map, layerId, onClick, onMouseEnter, onMouseLeave, interactive])

  return null
}

type MapGeoJSONData<P extends GeoJSON.GeoJsonProperties = GeoJSON.GeoJsonProperties> =
  | GeoJSON.FeatureCollection<GeoJSON.Geometry, P>
  | GeoJSON.Feature<GeoJSON.Geometry, P>
  | GeoJSON.Geometry
  | string

type MapFillPaint = NonNullable<MapLibreGL.FillLayerSpecification['paint']>
type MapLinePaint = NonNullable<MapLibreGL.LineLayerSpecification['paint']>

/** A rendered feature with strongly-typed `properties`. */
type MapGeoJSONFeature<P extends GeoJSON.GeoJsonProperties = GeoJSON.GeoJsonProperties> = Omit<
  MapLibreGL.MapGeoJSONFeature,
  'properties'
> & { properties: P }

/** Event payload passed to MapGeoJSON interaction callbacks. */
type MapGeoJSONEvent<P extends GeoJSON.GeoJsonProperties = GeoJSON.GeoJsonProperties> = {
  /** The feature under the cursor, with its typed GeoJSON properties. */
  feature: MapGeoJSONFeature<P>
  /** Longitude of the cursor at the time of the event. */
  longitude: number
  /** Latitude of the cursor at the time of the event. */
  latitude: number
  /** The underlying MapLibre mouse event for advanced use cases. */
  originalEvent: MapLibreGL.MapLayerMouseEvent
}

type MapGeoJSONProps<P extends GeoJSON.GeoJsonProperties = GeoJSON.GeoJsonProperties> = {
  /** GeoJSON data (FeatureCollection, Feature, Geometry) or a URL to fetch it from. */
  data: MapGeoJSONData<P>
  /** Optional unique identifier prefix for the source/layers. Auto-generated if not provided. */
  id?: string
  /**
   * Feature property to promote to the feature `id`. Required for hover
   * feature-state (`fillHoverPaint`) and stable `onHover`/`onClick` payloads.
   */
  promoteId?: string
  /**
   * Paint for the polygon fill layer. Merged on top of a theme-aware monochrome
   * surface tone (`fill-color`). Pass `false` to omit the fill layer entirely
   * (e.g. outlines only).
   */
  fillPaint?: MapFillPaint | false
  /**
   * Paint for the outline layer. Merged on top of a hairline default
   * (`line-color` = a near-surface neutral, `line-width` = 0.5) for thin
   * separators. Override `line-color` if your container differs, or pass
   * `false` to omit the layer.
   */
  linePaint?: MapLinePaint | false
  /**
   * Paint merged onto the fill layer for the feature under the cursor, applied
   * as a `case` expression keyed on hover feature-state. Requires `promoteId`.
   */
  fillHoverPaint?: MapFillPaint
  /** Callback when a feature is clicked. */
  onClick?: (e: MapGeoJSONEvent<P>) => void
  /** Callback fired when the hovered feature changes; `null` when the cursor leaves. */
  onHover?: (e: MapGeoJSONEvent<P> | null) => void
  /** Whether features respond to mouse events (default: false). */
  interactive?: boolean
  /** Optional MapLibre layer id to insert the layers before (z-order control). */
  beforeId?: string
}

// Monochrome defaults: a neutral-gray fill (hex of the grayscale chart tokens)
// with a fixed near-surface line for thin separators. Colors are hardcoded (not
// theme tokens), tuned for a typical light/dark surface. Override via
// `fillPaint` / `linePaint`.
const GEOJSON_DEFAULT_COLORS = {
  light: { fill: '#d4d4d4', line: '#ffffff' },
  dark: { fill: '#404040', line: '#171717' },
} satisfies Record<Theme, { fill: string; line: string }>

/**
 * Renders arbitrary GeoJSON as fill + outline layers on the map. Composes like
 * `MapRoute` / `MapArc` — drop it inside `<Map>` (typically with `blank`) for
 * choropleths and region/data maps. For full control over expressions and
 * multiple layers, manage layers directly via `useMap()` instead.
 */
function MapGeoJSON<P extends GeoJSON.GeoJsonProperties = GeoJSON.GeoJsonProperties>({
  data,
  id: propId,
  promoteId,
  fillPaint,
  linePaint,
  fillHoverPaint,
  onClick,
  onHover,
  interactive = false,
  beforeId,
}: MapGeoJSONProps<P>) {
  const { map, isLoaded, resolvedTheme } = useMap()
  const autoId = useId()
  const id = propId ?? autoId
  const sourceId = `geojson-source-${id}`
  const fillLayerId = `geojson-fill-${id}`
  const lineLayerId = `geojson-line-${id}`

  const defaults = GEOJSON_DEFAULT_COLORS[resolvedTheme]

  const showFill = fillPaint !== false
  const showLine = linePaint !== false

  const mergedFillPaint = useMemo(
    () => mergeHoverPaint({ 'fill-color': defaults.fill, ...(fillPaint || {}) }, fillHoverPaint),
    [defaults.fill, fillPaint, fillHoverPaint],
  )
  const mergedLinePaint = useMemo(
    () => ({
      'line-color': defaults.line,
      'line-width': 0.5,
      ...(linePaint || {}),
    }),
    [defaults.line, linePaint],
  )
  const latestRef = useRef({ onClick, onHover })
  latestRef.current = { onClick, onHover }

  // Add source on mount.
  useEffect(() => {
    if (!isLoaded || !map) return

    map.addSource(sourceId, {
      type: 'geojson',
      data,
      ...(promoteId ? { promoteId } : {}),
    })

    return () => {
      try {
        if (map.getLayer(lineLayerId)) map.removeLayer(lineLayerId)
        if (map.getLayer(fillLayerId)) map.removeLayer(fillLayerId)
        if (map.getSource(sourceId)) map.removeSource(sourceId)
      } catch {
        // style may be mid-reload
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoaded, map])

  // Sync data when it changes.
  useEffect(() => {
    if (!isLoaded || !map) return
    const source = map.getSource(sourceId) as MapLibreGL.GeoJSONSource | undefined
    source?.setData(data as never)
  }, [isLoaded, map, data, sourceId])

  // Sync layers and paint when visibility or styling changes.
  useEffect(() => {
    if (!isLoaded || !map) return

    const source = map.getSource(sourceId)
    if (!source) return

    if (showFill && !map.getLayer(fillLayerId)) {
      map.addLayer(
        {
          id: fillLayerId,
          type: 'fill',
          source: sourceId,
          paint: mergedFillPaint,
        },
        beforeId,
      )
    } else if (!showFill && map.getLayer(fillLayerId)) {
      map.removeLayer(fillLayerId)
    }

    if (showLine && !map.getLayer(lineLayerId)) {
      map.addLayer(
        {
          id: lineLayerId,
          type: 'line',
          source: sourceId,
          paint: mergedLinePaint,
        },
        beforeId,
      )
    } else if (!showLine && map.getLayer(lineLayerId)) {
      map.removeLayer(lineLayerId)
    }

    if (showFill && map.getLayer(fillLayerId)) {
      for (const [key, value] of Object.entries(mergedFillPaint)) {
        map.setPaintProperty(fillLayerId, key as keyof MapFillPaint, value as never)
      }
    }
    if (showLine && map.getLayer(lineLayerId)) {
      for (const [key, value] of Object.entries(mergedLinePaint)) {
        map.setPaintProperty(lineLayerId, key as keyof MapLinePaint, value as never)
      }
    }
  }, [
    isLoaded,
    map,
    sourceId,
    fillLayerId,
    lineLayerId,
    showFill,
    showLine,
    mergedFillPaint,
    mergedLinePaint,
    beforeId,
  ])

  // Interaction handlers (bound to the fill layer).
  useEffect(() => {
    if (!isLoaded || !map || !interactive || !showFill) return

    let hoveredId: string | number | null = null

    const setHover = (next: string | number | null) => {
      if (next === hoveredId) return
      const sourceExists = !!map.getSource(sourceId)
      if (hoveredId != null && sourceExists) {
        map.setFeatureState({ source: sourceId, id: hoveredId }, { hover: false })
      }
      hoveredId = next
      if (next != null && sourceExists) {
        map.setFeatureState({ source: sourceId, id: next }, { hover: true })
      }
    }

    const handleMouseMove = (e: MapLibreGL.MapLayerMouseEvent) => {
      const feature = e.features?.[0]
      if (!feature) return
      map.getCanvas().style.cursor = 'pointer'

      const featureId = feature.id
      if (featureId === hoveredId) return
      setHover(featureId ?? null)
      latestRef.current.onHover?.({
        feature: feature as unknown as MapGeoJSONFeature<P>,
        longitude: e.lngLat.lng,
        latitude: e.lngLat.lat,
        originalEvent: e,
      })
    }

    const handleMouseLeave = () => {
      setHover(null)
      map.getCanvas().style.cursor = ''
      latestRef.current.onHover?.(null)
    }

    const handleClick = (e: MapLibreGL.MapLayerMouseEvent) => {
      const feature = e.features?.[0]
      if (!feature) return
      latestRef.current.onClick?.({
        feature: feature as unknown as MapGeoJSONFeature<P>,
        longitude: e.lngLat.lng,
        latitude: e.lngLat.lat,
        originalEvent: e,
      })
    }

    map.on('mousemove', fillLayerId, handleMouseMove)
    map.on('mouseleave', fillLayerId, handleMouseLeave)
    map.on('click', fillLayerId, handleClick)

    return () => {
      map.off('mousemove', fillLayerId, handleMouseMove)
      map.off('mouseleave', fillLayerId, handleMouseLeave)
      map.off('click', fillLayerId, handleClick)
      setHover(null)
      map.getCanvas().style.cursor = ''
    }
  }, [isLoaded, map, fillLayerId, sourceId, interactive, showFill])

  return null
}

/** A single arc to render inside <MapArc data={...}>. */
type MapArcDatum = {
  /** Unique identifier for this arc. Required for hover state tracking and event payloads. */
  id: string | number
  /** Start coordinate as [longitude, latitude]. */
  from: [number, number]
  /** End coordinate as [longitude, latitude]. */
  to: [number, number]
}

/** Event payload passed to MapArc interaction callbacks. */
type MapArcEvent<T extends MapArcDatum = MapArcDatum> = {
  /** The arc datum that was hovered or clicked. */
  arc: T
  /** Longitude of the cursor at the time of the event. */
  longitude: number
  /** Latitude of the cursor at the time of the event. */
  latitude: number
  /** The underlying MapLibre mouse event for advanced use cases. */
  originalEvent: MapLibreGL.MapMouseEvent
}

type MapArcLinePaint = NonNullable<MapLibreGL.LineLayerSpecification['paint']>
type MapArcLineLayout = NonNullable<MapLibreGL.LineLayerSpecification['layout']>

type MapArcProps<T extends MapArcDatum = MapArcDatum> = {
  /** Array of arcs to render. Each arc must have a unique `id`. */
  data: T[]
  /** Optional unique identifier prefix for the arc source/layers. Auto-generated if not provided. */
  id?: string
  /**
   * How far each arc bows away from a straight line. `0` renders straight
   * lines; higher values bend further. Negative values bend to the opposite
   * side. Arcs are computed as a quadratic Bézier in lng/lat space; the
   * destination longitude is unwrapped relative to the origin so that arcs
   * cross the antimeridian via the shorter great-circle direction. (default: 0.2)
   */
  curvature?: number
  /** Number of samples used to render each curve. Higher = smoother. (default: 64) */
  samples?: number
  /**
   * MapLibre paint properties for the arc layer. Merged on top of sensible
   * defaults (`line-color: #4285F4`, `line-width: 2`, `line-opacity: 0.85`).
   * Any value can be a MapLibre expression for per-feature styling, every
   * field on each arc datum (besides `from`/`to`) is exposed via `["get", ...]`.
   */
  paint?: MapArcLinePaint
  /** MapLibre layout properties for the arc layer. Defaults to rounded joins/caps. */
  layout?: MapArcLineLayout
  /**
   * Paint properties applied to the arc currently under the cursor. Each key
   * is merged into `paint` as a `case` expression keyed on per-feature hover
   * state, so only the hovered arc changes appearance.
   */
  hoverPaint?: MapArcLinePaint
  /** Callback when an arc is clicked. */
  onClick?: (e: MapArcEvent<T>) => void
  /**
   * Callback fired when the hovered arc changes. Receives the cursor's
   * lng/lat at the moment of entry, and `null` when the cursor leaves the
   * last hovered arc.
   */
  onHover?: (e: MapArcEvent<T> | null) => void
  /** Whether arcs respond to mouse events (default: true). */
  interactive?: boolean
  /** Optional MapLibre layer id to insert the arc layers before (z-order control). */
  beforeId?: string
}

const DEFAULT_ARC_CURVATURE = 0.2
const DEFAULT_ARC_SAMPLES = 64
const ARC_HIT_MIN_WIDTH = 12
const ARC_HIT_PADDING = 6

const DEFAULT_ARC_PAINT: MapArcLinePaint = {
  'line-color': '#4285F4',
  'line-width': 2,
  'line-opacity': 0.85,
}

const DEFAULT_ARC_LAYOUT: MapArcLineLayout = {
  'line-join': 'round',
  'line-cap': 'round',
}

function buildArcCoordinates(
  from: [number, number],
  to: [number, number],
  curvature: number,
  samples: number,
): [number, number][] {
  const [x0, y0] = from
  const [xTo, y2] = to
  // Unwrap the destination longitude so |dx| <= 180. This makes arcs that
  // straddle the antimeridian (e.g. Tokyo -> San Francisco) bow the short way
  // across the Pacific instead of the long way around the globe. Resulting
  // longitudes may fall outside [-180, 180]; MapLibre renders them correctly
  // on the globe projection, and on mercator when world copies are enabled.
  const rawDx = xTo - x0
  const x2 = rawDx > 180 ? xTo - 360 : rawDx < -180 ? xTo + 360 : xTo
  const dx = x2 - x0
  const dy = y2 - y0
  const distance = Math.hypot(dx, dy)

  if (distance === 0 || curvature === 0) return [from, [x2, y2]]

  const mx = (x0 + x2) / 2
  const my = (y0 + y2) / 2
  const nx = -dy / distance
  const ny = dx / distance
  const offset = distance * curvature
  const cx = mx + nx * offset
  const cy = my + ny * offset

  const points: [number, number][] = []
  const segments = Math.max(2, Math.floor(samples))
  for (let i = 0; i <= segments; i += 1) {
    const t = i / segments
    const inv = 1 - t
    const x = inv * inv * x0 + 2 * inv * t * cx + t * t * x2
    const y = inv * inv * y0 + 2 * inv * t * cy + t * t * y2
    points.push([x, y])
  }
  return points
}

function MapArc<T extends MapArcDatum = MapArcDatum>({
  data,
  id: propId,
  curvature = DEFAULT_ARC_CURVATURE,
  samples = DEFAULT_ARC_SAMPLES,
  paint,
  layout,
  hoverPaint,
  onClick,
  onHover,
  interactive = true,
  beforeId,
}: MapArcProps<T>) {
  const { map, isLoaded } = useMap()
  const autoId = useId()
  const id = propId ?? autoId
  const sourceId = `arc-source-${id}`
  const layerId = `arc-layer-${id}`
  const hitLayerId = `arc-hit-layer-${id}`

  const mergedPaint = useMemo(
    () => mergeHoverPaint({ ...DEFAULT_ARC_PAINT, ...paint }, hoverPaint),
    [paint, hoverPaint],
  )
  const mergedLayout = useMemo(() => ({ ...DEFAULT_ARC_LAYOUT, ...layout }), [layout])

  const hitWidth = useMemo(() => {
    const w = paint?.['line-width'] ?? DEFAULT_ARC_PAINT['line-width']
    const base = typeof w === 'number' ? w : ARC_HIT_MIN_WIDTH
    return Math.max(base + ARC_HIT_PADDING, ARC_HIT_MIN_WIDTH)
  }, [paint])

  const geoJSON = useMemo<GeoJSON.FeatureCollection<GeoJSON.LineString>>(
    () => ({
      type: 'FeatureCollection',
      features: data.map((arc) => {
        const { from, to, ...properties } = arc
        return {
          type: 'Feature',
          properties,
          geometry: {
            type: 'LineString',
            coordinates: buildArcCoordinates(from, to, curvature, samples),
          },
        }
      }),
    }),
    [data, curvature, samples],
  )

  const latestRef = useRef({ data, onClick, onHover })
  latestRef.current = { data, onClick, onHover }

  // Add source and layers on mount.
  useEffect(() => {
    if (!isLoaded || !map) return

    map.addSource(sourceId, {
      type: 'geojson',
      data: geoJSON,
      promoteId: 'id',
    })

    map.addLayer(
      {
        id: hitLayerId,
        type: 'line',
        source: sourceId,
        layout: DEFAULT_ARC_LAYOUT,
        paint: {
          'line-color': 'rgba(0, 0, 0, 0)',
          'line-width': hitWidth,
          'line-opacity': 1,
        },
      },
      beforeId,
    )

    map.addLayer(
      {
        id: layerId,
        type: 'line',
        source: sourceId,
        layout: mergedLayout,
        paint: mergedPaint,
      },
      beforeId,
    )

    return () => {
      try {
        if (map.getLayer(layerId)) map.removeLayer(layerId)
        if (map.getLayer(hitLayerId)) map.removeLayer(hitLayerId)
        if (map.getSource(sourceId)) map.removeSource(sourceId)
      } catch {
        // ignore
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoaded, map])

  // Sync features when data / curvature / samples change.
  useEffect(() => {
    if (!isLoaded || !map) return
    const source = map.getSource(sourceId) as MapLibreGL.GeoJSONSource | undefined
    source?.setData(geoJSON)
  }, [isLoaded, map, geoJSON, sourceId])

  // Sync paint/layout when they change.
  useEffect(() => {
    if (!isLoaded || !map || !map.getLayer(layerId)) return
    for (const [key, value] of Object.entries(mergedPaint)) {
      map.setPaintProperty(layerId, key as keyof MapArcLinePaint, value as never)
    }
    for (const [key, value] of Object.entries(mergedLayout)) {
      map.setLayoutProperty(layerId, key as keyof MapArcLineLayout, value as never)
    }
    if (map.getLayer(hitLayerId)) {
      map.setPaintProperty(hitLayerId, 'line-width', hitWidth)
    }
  }, [isLoaded, map, layerId, hitLayerId, mergedPaint, mergedLayout, hitWidth])

  // Interaction handlers
  useEffect(() => {
    if (!isLoaded || !map || !interactive) return

    let hoveredId: string | number | null = null

    const setHover = (next: string | number | null) => {
      if (next === hoveredId) return
      const sourceExists = !!map.getSource(sourceId)
      if (hoveredId != null && sourceExists) {
        map.setFeatureState({ source: sourceId, id: hoveredId }, { hover: false })
      }
      hoveredId = next
      if (next != null && sourceExists) {
        map.setFeatureState({ source: sourceId, id: next }, { hover: true })
      }
    }

    const findArc = (featureId: string | number | undefined) =>
      featureId == null
        ? undefined
        : latestRef.current.data.find((arc) => String(arc.id) === String(featureId))

    const handleMouseMove = (e: MapLibreGL.MapLayerMouseEvent) => {
      const featureId = e.features?.[0]?.id as string | number | undefined
      if (featureId == null || featureId === hoveredId) return

      setHover(featureId)
      map.getCanvas().style.cursor = 'pointer'

      const arc = findArc(featureId)
      if (arc) {
        latestRef.current.onHover?.({
          arc: arc as T,
          longitude: e.lngLat.lng,
          latitude: e.lngLat.lat,
          originalEvent: e,
        })
      }
    }

    const handleMouseLeave = () => {
      setHover(null)
      map.getCanvas().style.cursor = ''
      latestRef.current.onHover?.(null)
    }

    const handleClick = (e: MapLibreGL.MapLayerMouseEvent) => {
      const arc = findArc(e.features?.[0]?.id as string | number | undefined)
      if (!arc) return
      latestRef.current.onClick?.({
        arc: arc as T,
        longitude: e.lngLat.lng,
        latitude: e.lngLat.lat,
        originalEvent: e,
      })
    }

    map.on('mousemove', hitLayerId, handleMouseMove)
    map.on('mouseleave', hitLayerId, handleMouseLeave)
    map.on('click', hitLayerId, handleClick)

    return () => {
      map.off('mousemove', hitLayerId, handleMouseMove)
      map.off('mouseleave', hitLayerId, handleMouseLeave)
      map.off('click', hitLayerId, handleClick)
      setHover(null)
      map.getCanvas().style.cursor = ''
    }
  }, [isLoaded, map, hitLayerId, sourceId, interactive])

  return null
}

type MapClusterLayerProps<P extends GeoJSON.GeoJsonProperties = GeoJSON.GeoJsonProperties> = {
  /** GeoJSON FeatureCollection data or URL to fetch GeoJSON from */
  data: string | GeoJSON.FeatureCollection<GeoJSON.Point, P>
  /** Maximum zoom level to cluster points on (default: 14) */
  clusterMaxZoom?: number
  /** Radius of each cluster when clustering points in pixels (default: 50) */
  clusterRadius?: number
  /** Colors for cluster circles: [small, medium, large] based on point count (default: ["#3b82f6", "#1d4ed8", "#1e3a8a"]) */
  clusterColors?: [string, string, string]
  /** Point count thresholds for color/size steps: [medium, large] (default: [100, 750]) */
  clusterThresholds?: [number, number]
  /** Color for unclustered individual points (default: "#3b82f6") */
  pointColor?: string
  /** Callback when an unclustered point is clicked */
  onPointClick?: (feature: GeoJSON.Feature<GeoJSON.Point, P>, coordinates: [number, number]) => void
  /** Callback when a cluster is clicked. If not provided, zooms into the cluster */
  onClusterClick?: (clusterId: number, coordinates: [number, number], pointCount: number) => void
}

const DEFAULT_CLUSTER_COLORS: [string, string, string] = ['#3b82f6', '#1d4ed8', '#1e3a8a']
const DEFAULT_CLUSTER_THRESHOLDS: [number, number] = [100, 750]

function MapClusterLayer<P extends GeoJSON.GeoJsonProperties = GeoJSON.GeoJsonProperties>({
  data,
  clusterMaxZoom = 14,
  clusterRadius = 50,
  clusterColors = DEFAULT_CLUSTER_COLORS,
  clusterThresholds = DEFAULT_CLUSTER_THRESHOLDS,
  pointColor = '#3b82f6',
  onPointClick,
  onClusterClick,
}: MapClusterLayerProps<P>) {
  const { map, isLoaded } = useMap()
  const id = useId()
  const sourceId = `cluster-source-${id}`
  const clusterLayerId = `clusters-${id}`
  const clusterCountLayerId = `cluster-count-${id}`
  const unclusteredLayerId = `unclustered-point-${id}`

  const stylePropsRef = useRef({
    clusterColors,
    clusterThresholds,
    pointColor,
  })

  // Add source and layers on mount
  useEffect(() => {
    if (!isLoaded || !map) return

    // Add clustered GeoJSON source
    map.addSource(sourceId, {
      type: 'geojson',
      data,
      cluster: true,
      clusterMaxZoom,
      clusterRadius,
    })

    // Add cluster circles layer
    map.addLayer({
      id: clusterLayerId,
      type: 'circle',
      source: sourceId,
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': [
          'step',
          ['get', 'point_count'],
          clusterColors[0],
          clusterThresholds[0],
          clusterColors[1],
          clusterThresholds[1],
          clusterColors[2],
        ],
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          20,
          clusterThresholds[0],
          30,
          clusterThresholds[1],
          40,
        ],
        'circle-stroke-width': 0.75,
        'circle-stroke-color': '#fff',
        'circle-opacity': 0.85,
      },
    })

    // Add cluster count text layer
    map.addLayer({
      id: clusterCountLayerId,
      type: 'symbol',
      source: sourceId,
      filter: ['has', 'point_count'],
      layout: {
        'text-field': '{point_count_abbreviated}',
        'text-font': ['Open Sans Semibold'],
        'text-size': 12,
      },
      paint: {
        'text-color': '#fff',
      },
    })

    // Add unclustered point layer
    map.addLayer({
      id: unclusteredLayerId,
      type: 'circle',
      source: sourceId,
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': pointColor,
        'circle-radius': 5,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#fff',
      },
    })

    return () => {
      try {
        if (map.getLayer(clusterCountLayerId)) map.removeLayer(clusterCountLayerId)
        if (map.getLayer(unclusteredLayerId)) map.removeLayer(unclusteredLayerId)
        if (map.getLayer(clusterLayerId)) map.removeLayer(clusterLayerId)
        if (map.getSource(sourceId)) map.removeSource(sourceId)
      } catch {
        // ignore
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoaded, map, sourceId])

  // Update source data when data prop changes (only for non-URL data)
  useEffect(() => {
    if (!isLoaded || !map || typeof data === 'string') return

    const source = map.getSource(sourceId) as MapLibreGL.GeoJSONSource
    if (source) {
      source.setData(data)
    }
  }, [isLoaded, map, data, sourceId])

  // Update layer styles when props change
  useEffect(() => {
    if (!isLoaded || !map) return

    const prev = stylePropsRef.current
    const colorsChanged =
      prev.clusterColors !== clusterColors || prev.clusterThresholds !== clusterThresholds

    // Update cluster layer colors and sizes
    if (map.getLayer(clusterLayerId) && colorsChanged) {
      map.setPaintProperty(clusterLayerId, 'circle-color', [
        'step',
        ['get', 'point_count'],
        clusterColors[0],
        clusterThresholds[0],
        clusterColors[1],
        clusterThresholds[1],
        clusterColors[2],
      ])
      map.setPaintProperty(clusterLayerId, 'circle-radius', [
        'step',
        ['get', 'point_count'],
        20,
        clusterThresholds[0],
        30,
        clusterThresholds[1],
        40,
      ])
    }

    // Update unclustered point layer color
    if (map.getLayer(unclusteredLayerId) && prev.pointColor !== pointColor) {
      map.setPaintProperty(unclusteredLayerId, 'circle-color', pointColor)
    }

    stylePropsRef.current = { clusterColors, clusterThresholds, pointColor }
  }, [
    isLoaded,
    map,
    clusterLayerId,
    unclusteredLayerId,
    clusterColors,
    clusterThresholds,
    pointColor,
  ])

  // Handle click events
  useEffect(() => {
    if (!isLoaded || !map) return

    // Cluster click handler - zoom into cluster
    const handleClusterClick = async (
      e: MapLibreGL.MapMouseEvent & {
        features?: MapLibreGL.MapGeoJSONFeature[]
      },
    ) => {
      const features = map.queryRenderedFeatures(e.point, {
        layers: [clusterLayerId],
      })
      if (!features.length) return

      const feature = features[0]
      const clusterId = feature.properties?.cluster_id as number
      const pointCount = feature.properties?.point_count as number
      const coordinates = (feature.geometry as GeoJSON.Point).coordinates as [number, number]

      if (onClusterClick) {
        onClusterClick(clusterId, coordinates, pointCount)
      } else {
        // Default behavior: zoom to cluster expansion zoom
        const source = map.getSource(sourceId) as MapLibreGL.GeoJSONSource
        const zoom = await source.getClusterExpansionZoom(clusterId)
        map.easeTo({
          center: coordinates,
          zoom,
        })
      }
    }

    // Unclustered point click handler
    const handlePointClick = (
      e: MapLibreGL.MapMouseEvent & {
        features?: MapLibreGL.MapGeoJSONFeature[]
      },
    ) => {
      if (!onPointClick || !e.features?.length) return

      const feature = e.features[0]
      const coordinates = (feature.geometry as GeoJSON.Point).coordinates.slice() as [
        number,
        number,
      ]

      // Handle world copies
      while (Math.abs(e.lngLat.lng - coordinates[0]) > 180) {
        coordinates[0] += e.lngLat.lng > coordinates[0] ? 360 : -360
      }

      onPointClick(feature as unknown as GeoJSON.Feature<GeoJSON.Point, P>, coordinates)
    }

    // Cursor style handlers
    const handleMouseEnterCluster = () => {
      map.getCanvas().style.cursor = 'pointer'
    }
    const handleMouseLeaveCluster = () => {
      map.getCanvas().style.cursor = ''
    }
    const handleMouseEnterPoint = () => {
      if (onPointClick) {
        map.getCanvas().style.cursor = 'pointer'
      }
    }
    const handleMouseLeavePoint = () => {
      map.getCanvas().style.cursor = ''
    }

    map.on('click', clusterLayerId, handleClusterClick)
    map.on('click', unclusteredLayerId, handlePointClick)
    map.on('mouseenter', clusterLayerId, handleMouseEnterCluster)
    map.on('mouseleave', clusterLayerId, handleMouseLeaveCluster)
    map.on('mouseenter', unclusteredLayerId, handleMouseEnterPoint)
    map.on('mouseleave', unclusteredLayerId, handleMouseLeavePoint)

    return () => {
      map.off('click', clusterLayerId, handleClusterClick)
      map.off('click', unclusteredLayerId, handlePointClick)
      map.off('mouseenter', clusterLayerId, handleMouseEnterCluster)
      map.off('mouseleave', clusterLayerId, handleMouseLeaveCluster)
      map.off('mouseenter', unclusteredLayerId, handleMouseEnterPoint)
      map.off('mouseleave', unclusteredLayerId, handleMouseLeavePoint)
    }
  }, [isLoaded, map, clusterLayerId, unclusteredLayerId, sourceId, onClusterClick, onPointClick])

  return null
}

export type {
  MapArcDatum,
  MapArcEvent,
  MapArcProps,
  MapClusterLayerProps,
  MapControlsProps,
  MapGeoJSONData,
  MapGeoJSONEvent,
  MapGeoJSONFeature,
  MapGeoJSONProps,
  MapMarkerProps,
  MapPopupProps,
  MapProps,
  MapRef,
  MapRouteProps,
  MapStyleOption,
  MapViewport,
  MarkerContentProps,
  MarkerLabelProps,
  MarkerPopupProps,
  MarkerTooltipProps,
}
export {
  Map,
  MapArc,
  MapClusterLayer,
  MapControls,
  MapGeoJSON,
  MapMarker,
  MapPopup,
  MapRoute,
  MarkerContent,
  MarkerLabel,
  MarkerPopup,
  MarkerTooltip,
  useMap,
}
