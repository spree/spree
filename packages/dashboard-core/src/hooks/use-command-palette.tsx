import { useHotkey } from '@tanstack/react-hotkeys'
import { createContext, type ReactNode, useContext, useMemo, useState } from 'react'

interface CommandPaletteState {
  open: boolean
  setOpen: (open: boolean) => void
}

const CommandPaletteContext = createContext<CommandPaletteState | null>(null)

/**
 * Mounts at the app shell so the top-bar trigger, the global ⌘K shortcut, and
 * the palette dialog itself share a single source of truth without
 * prop-drilling through layouts.
 */
export function CommandPaletteProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false)

  useHotkey('Mod+K', () => {
    setOpen((prev) => !prev)
  })

  const value = useMemo<CommandPaletteState>(() => ({ open, setOpen }), [open])

  return <CommandPaletteContext.Provider value={value}>{children}</CommandPaletteContext.Provider>
}

export function useCommandPalette(): CommandPaletteState {
  const ctx = useContext(CommandPaletteContext)
  if (!ctx) {
    throw new Error('useCommandPalette must be used within a CommandPaletteProvider')
  }
  return ctx
}
