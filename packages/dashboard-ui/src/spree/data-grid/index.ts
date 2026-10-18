// Column definitions name the table library through this package, which owns
// its version — consumers never install it themselves.
export type { ColumnDef as DataGridColumn } from '@tanstack/react-table'
export {
  DecimalCell,
  MoneyCell,
  NumberCell,
  ReadOnlyCell,
  SelectCell,
  SwitchCell,
  TextCell,
} from './cells'
export { useDataGridContext } from './context'
export { DataGrid } from './data-grid'
export { editableRowIndex } from './helpers'
export type { CellCoords, RenderSectionHeader } from './types'
