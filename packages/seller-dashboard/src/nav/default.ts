import { i18n, nav } from '@spree/dashboard-core'
import { ClipboardCheckIcon, StoreIcon, UsersIcon } from 'lucide-react'
import { OnboardingNavBadge } from '../components/onboarding-nav-badge'

// The panel's built-in sidebar. Registered into the same registry a plugin
// writes to, so a marketplace can remove, reorder or add beside these with
// `defineDashboardPlugin({ nav: ... })` instead of forking the chrome.
//
// Positions leave room on either side (100/200/…) exactly as the operator's
// dashboard does, so a plugin slots between built-ins without renumbering.
//
// Subjects are the seller-branch CanCanCan subjects the API's `/me`
// serializes; an entry a member cannot act on is hidden by the same
// permission filter the operator's sidebar uses.

nav.add({
  key: 'profile',
  label: i18n.t('nav.profile'),
  path: '/',
  icon: StoreIcon,
  position: 100,
  subject: 'seller_profile',
})

// First in the rail while a seller is still being admitted: it is the only
// thing that matters until they are approved. A marketplace that admits
// sellers some other way removes it like any other entry.
nav.add({
  key: 'onboarding',
  label: i18n.t('nav.onboarding'),
  path: '/onboarding',
  icon: ClipboardCheckIcon,
  position: 150,
  subject: 'seller_profile',
  badge: OnboardingNavBadge,
})

nav.add({
  key: 'team',
  label: i18n.t('nav.team'),
  path: '/team',
  icon: UsersIcon,
  position: 200,
  subject: 'seller_profile',
  action: 'update',
})
