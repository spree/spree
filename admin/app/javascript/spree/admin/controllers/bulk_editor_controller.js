import { Controller } from '@hotwired/stimulus'

// Spreadsheet-style bulk editor controller
// Features:
// - Multi-cell selection (Shift+Click, Click+Drag)
// - Copy/Paste (Ctrl+C/Cmd+C, Ctrl+V/Cmd+V)
// - Fill down (Ctrl+D/Cmd+D or drag fill handle)
// - Keyboard navigation (Arrow keys, Tab, Enter)
// - Bulk clear (Delete/Backspace)
// - Fill handle (blue dot) for dragging values to adjacent cells
//
// Usage:
//   <form data-controller="bulk-editor"
//         data-action="keydown.ctrl+a->bulk-editor#selectAll keydown.meta+a->bulk-editor#selectAll">
//     <table data-bulk-editor-target="table">
//       <tr data-bulk-editor-target="row">
//         <td>
//           <input data-bulk-editor-target="cell"
//                  data-row="0" data-col="0"
//                  data-action="focus->bulk-editor#onCellFocus
//                               blur->bulk-editor#onCellBlur
//                               keydown.ctrl+c->bulk-editor#copy
//                               keydown.meta+c->bulk-editor#copy
//                               keydown.ctrl+v->bulk-editor#paste
//                               keydown.meta+v->bulk-editor#paste
//                               keydown.ctrl+d->bulk-editor#fillDown
//                               keydown.meta+d->bulk-editor#fillDown
//                               keydown.up->bulk-editor#navigateUp
//                               keydown.down->bulk-editor#navigateDown
//                               keydown.left->bulk-editor#navigateLeft
//                               keydown.right->bulk-editor#navigateRight
//                               keydown.shift+up->bulk-editor#selectUp
//                               keydown.shift+down->bulk-editor#selectDown
//                               keydown.shift+left->bulk-editor#selectLeft
//                               keydown.shift+right->bulk-editor#selectRight
//                               keydown.tab->bulk-editor#navigateRight
//                               keydown.shift+tab->bulk-editor#navigateLeft
//                               keydown.enter->bulk-editor#navigateDown
//                               keydown->bulk-editor#handleKeydown
//                               input->bulk-editor#markDirty">
//
// Note: Delete/Backspace keys are handled via handleKeydown since Stimulus
// doesn't support them as keyboard event filters.
//         </td>
//       </tr>
//     </table>
//   </form>
//
export default class extends Controller {
  static targets = ['table', 'row', 'cell', 'saveButton', 'statusBar']

  connect() {
    this.dirtyInputs = new Set()
    this.selectedCells = new Set()
    this.anchorCell = null      // Starting point for range selection
    this.extendCell = null      // Current end point for range selection (Shift+Arrow)
    this.focusedCell = null
    this.editingCell = null     // Cell currently in edit mode
    this.isSelecting = false
    this.isDraggingFillHandle = false
    this.isMouseOverFillHandle = false
    this.fillStartCell = null
    this.copiedValues = []

    // Create fill handle element if not present
    this.createFillHandle()

    // Make all cells read-only initially (selection mode)
    this.cellTargets.forEach(cell => {
      cell.readOnly = true
    })

    this.boundHandleBeforeUnload = this.handleBeforeUnload.bind(this)
    this.boundHandleMouseUp = this.handleMouseUp.bind(this)
    this.boundHandleMouseMove = this.handleMouseMove.bind(this)

    window.addEventListener('beforeunload', this.boundHandleBeforeUnload)
    document.addEventListener('mouseup', this.boundHandleMouseUp)
    document.addEventListener('mousemove', this.boundHandleMouseMove)
  }

  disconnect() {
    window.removeEventListener('beforeunload', this.boundHandleBeforeUnload)
    document.removeEventListener('mouseup', this.boundHandleMouseUp)
    document.removeEventListener('mousemove', this.boundHandleMouseMove)
  }

  // ==================== Fill Handle ====================

  createFillHandle() {
    if (this.fillHandle) return

    this.fillHandle = document.createElement('div')
    this.fillHandle.className = 'fill-handle'
    this.fillHandle.addEventListener('mousedown', this.onFillHandleMouseDown.bind(this))
    this.fillHandle.addEventListener('mouseenter', () => { this.isMouseOverFillHandle = true })
    this.fillHandle.addEventListener('mouseleave', () => { this.isMouseOverFillHandle = false })
    this.element.appendChild(this.fillHandle)
  }

  positionFillHandle() {
    if (!this.fillHandle || !this.focusedCell) {
      this.hideFillHandle()
      return
    }

    const cell = this.focusedCell
    const cellRect = cell.getBoundingClientRect()
    const containerRect = this.element.getBoundingClientRect()

    // Position at bottom-right corner of the focused cell
    this.fillHandle.style.display = 'block'
    this.fillHandle.style.left = `${cellRect.right - containerRect.left - 4}px`
    this.fillHandle.style.top = `${cellRect.bottom - containerRect.top - 4}px`
  }

  hideFillHandle() {
    if (this.fillHandle) {
      this.fillHandle.style.display = 'none'
    }
  }

  onFillHandleMouseDown(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.focusedCell) return

    this.isDraggingFillHandle = true
    this.fillStartCell = this.focusedCell
    this.fillStartValue = this.focusedCell.value

    // Store the starting selection
    this.fillStartCoords = this.getCellCoords(this.fillStartCell)

    // Ensure the starting cell is selected
    this.clearSelection()
    this.selectCell(this.fillStartCell)

    // Add visual indicator
    this.element.classList.add('fill-dragging')
  }

  handleMouseMove(event) {
    if (!this.isDraggingFillHandle) return

    // Find the cell under the cursor
    const cellUnderCursor = this.getCellAtPoint(event.clientX, event.clientY)
    if (!cellUnderCursor) return

    // Select range from start to current (vertical or horizontal)
    this.clearSelection()
    this.selectRange(this.fillStartCell, cellUnderCursor)
  }

  getCellAtPoint(x, y) {
    // First try using document.elementFromPoint
    let element = document.elementFromPoint(x, y)

    // Walk up to find a cell target
    while (element && element !== this.element) {
      if (this.cellTargets.includes(element)) {
        return element
      }
      element = element.parentElement
    }

    // Fallback: find closest cell by checking expanded bounding boxes
    // This handles gaps between cells
    let closestCell = null
    let closestDistance = Infinity

    for (const cell of this.cellTargets) {
      const rect = cell.getBoundingClientRect()
      // Expand the hit area slightly
      const padding = 5
      if (x >= rect.left - padding && x <= rect.right + padding &&
          y >= rect.top - padding && y <= rect.bottom + padding) {
        const centerX = rect.left + rect.width / 2
        const centerY = rect.top + rect.height / 2
        const distance = Math.sqrt(Math.pow(x - centerX, 2) + Math.pow(y - centerY, 2))
        if (distance < closestDistance) {
          closestDistance = distance
          closestCell = cell
        }
      }
    }

    return closestCell
  }

  handleMouseUp() {
    if (this.isDraggingFillHandle) {
      this.completeFillDrag()
    }
    this.isSelecting = false
    this.isDraggingFillHandle = false
    this.element.classList.remove('fill-dragging')
  }

  completeFillDrag() {
    if (!this.fillStartCell || this.selectedCells.size < 2) return

    const fillValue = this.fillStartValue

    // Apply value to all selected cells except the start cell
    this.selectedCells.forEach(cell => {
      if (cell !== this.fillStartCell) {
        this.setCellValue(cell, fillValue)
      }
    })

    const filledCount = this.selectedCells.size - 1
    if (filledCount > 0) {
      this.showNotification(`Filled ${filledCount} cell(s)`)
    }

    // Clear selection and return focus to the start cell
    this.clearSelection()
    this.fillStartCell.focus()
    this.selectCell(this.fillStartCell)
    this.anchorCell = this.fillStartCell
  }

  // ==================== Cell Selection ====================

  onCellFocus(event) {
    const cell = event.target
    this.focusedCell = cell

    // Exit edit mode if focusing a different cell
    if (this.editingCell && this.editingCell !== cell) {
      this.exitEditMode()
    }

    if (!event.shiftKey) {
      this.clearSelection()
      this.anchorCell = cell
      this.extendCell = null  // Reset extend tracking
    }
    this.selectCell(cell)
    this.positionFillHandle()
  }

  onCellBlur() {
    // Delay hiding to allow for fill handle clicks
    // Use longer delay and check if mouse is over fill handle
    setTimeout(() => {
      if (this.isDraggingFillHandle || this.isMouseOverFillHandle) return
      if (this.cellTargets.includes(document.activeElement)) return

      this.focusedCell = null
      this.hideFillHandle()
    }, 150)
  }

  onCellDoubleClick(event) {
    const cell = event.target
    this.enterEditMode(cell)
  }

  onCellMouseDown(event) {
    const cell = event.target

    if (event.shiftKey && this.anchorCell) {
      event.preventDefault()
      this.selectRange(this.anchorCell, cell)
    } else {
      this.clearSelection()
      this.anchorCell = cell
      this.selectCell(cell)
      this.isSelecting = true
    }
  }

  onCellMouseEnter(event) {
    if (!this.isSelecting || !this.anchorCell) return
    const cell = event.target
    this.selectRange(this.anchorCell, cell)
  }

  selectCell(cell) {
    cell.classList.add('selected')
    this.selectedCells.add(cell)
    this.updateStatusBar()
    this.updateSelectionOverlay()
  }

  deselectCell(cell) {
    cell.classList.remove('selected')
    this.selectedCells.delete(cell)
  }

  clearSelection() {
    this.selectedCells.forEach(cell => this.deselectCell(cell))
    this.selectedCells.clear()
    this.updateStatusBar()
    this.hideSelectionOverlay()
  }

  selectRange(startCell, endCell) {
    const startCoords = this.getCellCoords(startCell)
    const endCoords = this.getCellCoords(endCell)

    const minRow = Math.min(startCoords.row, endCoords.row)
    const maxRow = Math.max(startCoords.row, endCoords.row)
    const minCol = Math.min(startCoords.col, endCoords.col)
    const maxCol = Math.max(startCoords.col, endCoords.col)

    // Store selection bounds
    this.selectionBounds = { minRow, maxRow, minCol, maxCol }

    this.clearSelection()

    this.cellTargets.forEach(cell => {
      const coords = this.getCellCoords(cell)
      if (coords.row >= minRow && coords.row <= maxRow &&
          coords.col >= minCol && coords.col <= maxCol) {
        cell.classList.add('selected')
        this.selectedCells.add(cell)
      }
    })

    this.updateStatusBar()
    this.updateSelectionOverlay()
  }

  // Selection overlay - draws a single border around the entire selection
  createSelectionOverlay() {
    if (this.selectionOverlay) return

    this.selectionOverlay = document.createElement('div')
    this.selectionOverlay.className = 'selection-overlay'
    this.element.appendChild(this.selectionOverlay)
  }

  updateSelectionOverlay() {
    if (this.selectedCells.size === 0) {
      this.hideSelectionOverlay()
      return
    }

    this.createSelectionOverlay()

    // Get bounding rect of all selected cells
    const cells = Array.from(this.selectedCells)
    const containerRect = this.element.getBoundingClientRect()

    let minLeft = Infinity, minTop = Infinity
    let maxRight = -Infinity, maxBottom = -Infinity

    cells.forEach(cell => {
      const rect = cell.getBoundingClientRect()
      minLeft = Math.min(minLeft, rect.left)
      minTop = Math.min(minTop, rect.top)
      maxRight = Math.max(maxRight, rect.right)
      maxBottom = Math.max(maxBottom, rect.bottom)
    })

    // Position overlay relative to container
    this.selectionOverlay.style.display = 'block'
    this.selectionOverlay.style.left = `${minLeft - containerRect.left}px`
    this.selectionOverlay.style.top = `${minTop - containerRect.top}px`
    this.selectionOverlay.style.width = `${maxRight - minLeft}px`
    this.selectionOverlay.style.height = `${maxBottom - minTop}px`
  }

  hideSelectionOverlay() {
    if (this.selectionOverlay) {
      this.selectionOverlay.style.display = 'none'
    }
  }

  selectAll(event) {
    event.preventDefault()
    this.clearSelection()
    this.cellTargets.forEach(cell => this.selectCell(cell))
  }

  // ==================== Keyboard Events ====================

  // Handle keys not supported by Stimulus keyboard event filters
  handleKeydown(event) {
    const cell = event.target

    // Enter key - toggle edit mode or move down if already editing
    if (event.key === 'Enter') {
      event.preventDefault()
      if (this.editingCell === cell) {
        // Exit edit mode and move down
        this.exitEditMode()
        this.navigate('down')
      } else {
        // Enter edit mode
        this.enterEditMode(cell)
      }
      return
    }

    // Escape key - exit edit mode and revert changes
    if (event.key === 'Escape') {
      if (this.editingCell) {
        event.preventDefault()
        this.exitEditMode(true) // true = revert to original value
      }
      return
    }

    // If in edit mode, allow normal typing
    if (this.editingCell === cell) {
      return
    }

    // Delete/Backspace - clear selected cells (only in selection mode)
    if (event.key === 'Delete' || event.key === 'Backspace') {
      event.preventDefault()
      this.clearCells(event)
      return
    }

    // Start editing on any printable character
    if (event.key.length === 1 && !event.ctrlKey && !event.metaKey) {
      this.enterEditMode(cell, true) // true = clear existing value
    }
  }

  enterEditMode(cell) {
    // Exit any existing edit mode
    if (this.editingCell && this.editingCell !== cell) {
      this.exitEditMode()
    }

    this.editingCell = cell
    this.editingCellOriginalValue = cell.value // Store value for Escape revert
    cell.readOnly = false
    cell.classList.add('editing')
    // Select all text for easy replacement
    cell.select()
  }

  exitEditMode(revert = false) {
    if (!this.editingCell) return

    // Revert value if Escape was pressed
    if (revert && this.editingCellOriginalValue !== undefined) {
      this.editingCell.value = this.editingCellOriginalValue
    }

    this.editingCell.readOnly = true
    this.editingCell.classList.remove('editing')
    this.editingCell = null
    this.editingCellOriginalValue = undefined
  }

  // ==================== Keyboard Navigation ====================

  navigateUp(event) {
    if (this.editingCell) return // Allow cursor movement in edit mode
    event.preventDefault()
    this.navigate('up')
  }

  navigateDown(event) {
    if (this.editingCell) return
    event.preventDefault()
    this.navigate('down')
  }

  navigateLeft(event) {
    // Tab always navigates (exits edit mode), arrow keys only in selection mode
    if (this.editingCell && event.key !== 'Tab') return
    event.preventDefault()
    this.navigate('left')
  }

  navigateRight(event) {
    // Tab always navigates (exits edit mode), arrow keys only in selection mode
    if (this.editingCell && event.key !== 'Tab') return
    event.preventDefault()
    this.navigate('right')
  }

  selectUp(event) {
    if (this.editingCell) return
    event.preventDefault()
    this.extendSelection('up')
  }

  selectDown(event) {
    if (this.editingCell) return
    event.preventDefault()
    this.extendSelection('down')
  }

  selectLeft(event) {
    if (this.editingCell) return
    event.preventDefault()
    this.extendSelection('left')
  }

  selectRight(event) {
    if (this.editingCell) return
    event.preventDefault()
    this.extendSelection('right')
  }

  navigate(direction) {
    const activeCell = document.activeElement
    if (!this.cellTargets.includes(activeCell)) return

    // Exit edit mode when navigating
    this.exitEditMode()

    const coords = this.getCellCoords(activeCell)
    const targetCell = this.getAdjacentCell(coords, direction)

    if (targetCell) {
      this.clearSelection()
      this.anchorCell = targetCell
      this.extendCell = null  // Reset extend tracking
      targetCell.focus()
      this.selectCell(targetCell)
    }
  }

  extendSelection(direction) {
    const activeCell = document.activeElement
    if (!this.cellTargets.includes(activeCell)) return

    // Use extendCell if we're continuing a selection, otherwise start from active cell
    const fromCell = this.extendCell || activeCell
    const coords = this.getCellCoords(fromCell)
    const targetCell = this.getAdjacentCell(coords, direction)

    if (targetCell) {
      // Set anchor if not already set
      if (!this.anchorCell) {
        this.anchorCell = activeCell
      }
      // Track the extend endpoint
      this.extendCell = targetCell
      // Select range from anchor to new extend point
      this.selectRange(this.anchorCell, targetCell)
    }
  }

  getAdjacentCell(coords, direction) {
    let targetRow = coords.row
    let targetCol = coords.col

    switch (direction) {
      case 'up': targetRow--; break
      case 'down': targetRow++; break
      case 'left': targetCol--; break
      case 'right': targetCol++; break
    }

    return this.getCellAt(targetRow, targetCol)
  }

  // ==================== Copy / Paste / Fill ====================

  copy(event) {
    event?.preventDefault()
    if (this.selectedCells.size === 0) return

    // Store values from selected cells
    this.copiedValues = Array.from(this.selectedCells).map(cell => ({
      value: cell.value,
      coords: this.getCellCoords(cell)
    }))

    // Sort by row then column for proper paste order
    this.copiedValues.sort((a, b) => {
      if (a.coords.row !== b.coords.row) return a.coords.row - b.coords.row
      return a.coords.col - b.coords.col
    })

    // Also copy to clipboard
    if (this.selectedCells.size === 1) {
      const value = Array.from(this.selectedCells)[0].value
      navigator.clipboard?.writeText(value)
    } else {
      // For multiple cells, create tab-separated values
      const rows = new Map()
      this.copiedValues.forEach(({ value, coords }) => {
        if (!rows.has(coords.row)) rows.set(coords.row, [])
        rows.get(coords.row).push(value)
      })
      const tsv = Array.from(rows.values()).map(row => row.join('\t')).join('\n')
      navigator.clipboard?.writeText(tsv)
    }

    this.showNotification(`${this.copiedValues.length} cell(s) copied`)
  }

  paste(event) {
    event?.preventDefault()
    if (this.copiedValues.length === 0) return
    if (this.selectedCells.size === 0) return

    const targetCells = Array.from(this.selectedCells).sort((a, b) => {
      const coordsA = this.getCellCoords(a)
      const coordsB = this.getCellCoords(b)
      if (coordsA.row !== coordsB.row) return coordsA.row - coordsB.row
      return coordsA.col - coordsB.col
    })

    // If single value copied, paste to all selected cells
    if (this.copiedValues.length === 1) {
      const value = this.copiedValues[0].value
      targetCells.forEach(cell => {
        this.setCellValue(cell, value)
      })
      this.showNotification(`Pasted to ${targetCells.length} cell(s)`)
      return
    }

    // If multiple values, try to match the pattern
    const startCell = targetCells[0]
    const startCoords = this.getCellCoords(startCell)
    const copyStartCoords = this.copiedValues[0].coords

    this.copiedValues.forEach(copied => {
      const rowOffset = copied.coords.row - copyStartCoords.row
      const colOffset = copied.coords.col - copyStartCoords.col
      const targetCell = this.getCellAt(startCoords.row + rowOffset, startCoords.col + colOffset)
      if (targetCell) {
        this.setCellValue(targetCell, copied.value)
      }
    })

    this.showNotification(`Pasted ${this.copiedValues.length} cell(s)`)
  }

  fillDown(event) {
    event?.preventDefault()
    if (this.selectedCells.size < 2) return

    // Get selected cells sorted by row
    const cells = Array.from(this.selectedCells).sort((a, b) => {
      const coordsA = this.getCellCoords(a)
      const coordsB = this.getCellCoords(b)
      if (coordsA.col !== coordsB.col) return coordsA.col - coordsB.col
      return coordsA.row - coordsB.row
    })

    // Group by column
    const columnGroups = new Map()
    cells.forEach(cell => {
      const col = this.getCellCoords(cell).col
      if (!columnGroups.has(col)) {
        columnGroups.set(col, [])
      }
      columnGroups.get(col).push(cell)
    })

    // Fill each column with the first value in that column
    let filledCount = 0
    columnGroups.forEach(columnCells => {
      if (columnCells.length < 2) return
      const sourceValue = columnCells[0].value
      for (let i = 1; i < columnCells.length; i++) {
        this.setCellValue(columnCells[i], sourceValue)
        filledCount++
      }
    })

    if (filledCount > 0) {
      this.showNotification(`Filled ${filledCount} cell(s)`)
    }
  }

  clearCells(event) {
    if (this.selectedCells.size > 1) {
      event.preventDefault()
      this.selectedCells.forEach(cell => {
        this.setCellValue(cell, '')
      })
      this.showNotification(`Cleared ${this.selectedCells.size} cell(s)`)
    }
  }

  setCellValue(cell, value, updateOriginal = false) {
    cell.value = value
    // Optionally update the original value so cell doesn't appear dirty
    if (updateOriginal) {
      cell.dataset.originalValue = value
    }
    cell.dispatchEvent(new Event('input', { bubbles: true }))
  }

  // ==================== Dirty State Tracking ====================

  markDirty(event) {
    const input = event.target
    const originalValue = input.dataset.originalValue ?? ''
    const currentValue = input.value

    if (currentValue !== originalValue) {
      this.dirtyInputs.add(input)
    } else {
      this.dirtyInputs.delete(input)
    }

    this.updateSaveButton()
  }

  updateSaveButton() {
    if (!this.hasSaveButtonTarget) return
    // Keep save button always enabled to allow saving
  }

  handleBeforeUnload(event) {
    if (this.dirtyInputs.size > 0) {
      event.preventDefault()
      event.returnValue = ''
    }
  }

  // ==================== Helpers ====================

  getCellCoords(cell) {
    return {
      row: parseInt(cell.dataset.row, 10),
      col: parseInt(cell.dataset.col, 10)
    }
  }

  getCellAt(row, col) {
    return this.cellTargets.find(cell => {
      const coords = this.getCellCoords(cell)
      return coords.row === row && coords.col === col
    })
  }

  updateStatusBar() {
    if (!this.hasStatusBarTarget) return
    const count = this.selectedCells.size
    if (count > 1) {
      this.statusBarTarget.textContent = `${count} cells selected`
      this.statusBarTarget.classList.remove('hidden')
    } else {
      this.statusBarTarget.classList.add('hidden')
    }
  }

  showNotification(message) {
    // Use existing toast/notification system if available
    if (window.Spree?.Admin?.showNotification) {
      window.Spree.Admin.showNotification(message)
      return
    }

    // Fallback: update status bar
    if (this.hasStatusBarTarget) {
      this.statusBarTarget.textContent = message
      this.statusBarTarget.classList.remove('hidden')
      setTimeout(() => {
        this.updateStatusBar()
      }, 2000)
    }
  }

  // ==================== Getters ====================

  get isDirty() {
    return this.dirtyInputs.size > 0
  }
}
