// i18n bootstrap for `@spree/dashboard`.
//
// 1. The side-effect import below initializes i18next with the framework's
//    base translation namespace (`admin.actions.*`, `admin.common.*`,
//    `admin.fields.<simple>.*`, etc.) shipped in `@spree/dashboard-core`.
// 2. We then merge the app's resource bundle (`admin.nav.*`, resource pages,
//    integrations) so callers can `t('admin.nav.orders')` alongside
//    `t('admin.actions.save')` from the same namespace.
//
// Plugin authors follow the same pattern from their entry module:
//
//     import { i18n } from '@spree/dashboard-core'
//     import myEn from './locales/en.json'
//     i18n.addResourceBundle('en', 'translation', myEn.admin, true, true)
//
// `deep: true` + `overwrite: true` merge nested objects without dropping
// keys the framework already provided; plugin keys win on collision.
import { i18n } from '@spree/dashboard-core'
import en from './locales/en.json'

i18n.addResourceBundle('en', 'translation', en, true, true)
