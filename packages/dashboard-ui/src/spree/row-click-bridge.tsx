import { useEffect } from 'react'

export function useRowClickBridge(dataAttribute: string, onClick: (id: string) => void) {
  useEffect(() => {
    function handler(e: MouseEvent) {
      const target = e.target as HTMLElement | null
      const cell = target?.closest(`[${dataAttribute}]`) as HTMLElement | null
      if (!cell) return
      const id = cell.getAttribute(dataAttribute)
      if (!id) return
      e.preventDefault()
      onClick(id)
    }
    document.addEventListener('click', handler)
    return () => document.removeEventListener('click', handler)
  }, [dataAttribute, onClick])
}
