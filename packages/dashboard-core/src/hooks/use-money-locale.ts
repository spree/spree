import { useTranslation } from 'react-i18next'

/**
 * The locale money is shown and typed in: the dashboard language of the person
 * using it, whatever the currency or market. Someone who writes `1.234,56`
 * types that for dollars too, and the field reads it back the same way it
 * displayed it. The API only ever receives canonical `"1234.56"`.
 *
 * @returns a BCP 47 locale such as `de` or `en`
 */
export function useMoneyLocale(): string {
  const { i18n } = useTranslation()
  return i18n.language || 'en'
}
