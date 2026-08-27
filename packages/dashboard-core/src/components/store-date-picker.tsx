import { DatePicker, type DatePickerProps } from '@spree/dashboard-ui'
import { useOptionalStore } from '../providers/store-provider'

/**
 * Drop-in `<DatePicker>` that pulls the timezone from `<StoreProvider>` so
 * every datetime in the admin SPA is interpreted in the store's timezone
 * regardless of where the admin is logged in from.
 *
 * Use this in every admin form, filter, and sheet that touches a date.
 * Only reach for the bare `<DatePicker>` when you need to override the
 * timezone explicitly (rare).
 */
function StoreDatePicker(props: Omit<DatePickerProps, 'timezone'>) {
  // Optional: a panel with no store context (a seller's) falls back to the
  // browser's zone rather than refusing to render a date field.
  const store = useOptionalStore()
  const timezone = store?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC'

  return <DatePicker {...props} timezone={timezone} />
}

export { StoreDatePicker }
