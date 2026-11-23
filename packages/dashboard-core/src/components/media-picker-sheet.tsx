import {
  MediaPickerDialog,
  type MediaPickerDialogProps,
  type MediaPickerOption,
} from './media-picker-dialog'

export type { MediaPickerOption, MediaPickerSearchOptions } from './media-picker-dialog'

/** @deprecated Renamed to `MediaPickerDialogProps`; removed in the next minor release. */
export type MediaPickerSheetProps<T extends MediaPickerOption> = MediaPickerDialogProps<T>

/**
 * @deprecated The picker is now a dialog; use `MediaPickerDialog`. This name
 * keeps working until the next minor release.
 */
export function MediaPickerSheet<T extends MediaPickerOption>(props: MediaPickerDialogProps<T>) {
  // Off unless asked for: a sheet-era `search` ignores the sort and filter
  // options, so the controls would change nothing.
  return <MediaPickerDialog browseControls={false} {...props} />
}
