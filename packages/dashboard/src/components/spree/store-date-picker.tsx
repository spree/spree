import { useStore } from '@spree/dashboard-core'
import { DatePicker, type DatePickerProps } from '@spree/dashboard-ui'

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
  const { timezone } = useStore()
  return <DatePicker {...props} timezone={timezone} />
}

export { StoreDatePicker }
