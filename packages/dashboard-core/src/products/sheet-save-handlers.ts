import { useCallback, useRef, useState } from 'react'

/** Persists a slot widget's own edits; resolves `false` to keep the sheet open. */
export type SheetSaveHandler = () => Promise<boolean>

/**
 * Lets widgets in a product-page sheet's slot save their own records when the
 * sheet's Done is pressed. The sheet's fields ride the product's Save, but a
 * widget writing a different record (a variant's custom fields) has no other
 * moment that matches what the merchant expects: Done keeps, Cancel drops.
 */
export function useSheetSaveHandlers() {
  const handlers = useRef(new Set<SheetSaveHandler>())
  const [saving, setSaving] = useState(false)

  /** Registers a handler; the returned function unregisters it. */
  const onSave = useCallback((handler: SheetSaveHandler) => {
    handlers.current.add(handler)
    return () => {
      handlers.current.delete(handler)
    }
  }, [])

  // A widget that throws keeps the sheet open like one that resolves `false`,
  // rather than escaping as an unhandled rejection from the Done click.
  const saveAll = useCallback(async () => {
    setSaving(true)
    try {
      const results = await Promise.allSettled([...handlers.current].map((handler) => handler()))
      return results.every((result) => result.status === 'fulfilled' && result.value)
    } finally {
      setSaving(false)
    }
  }, [])

  return { onSave, saveAll, saving }
}
