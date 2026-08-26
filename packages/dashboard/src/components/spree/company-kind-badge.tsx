import { Badge } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/** Legal entity vs organizational unit — the two node kinds, fixed. */
export function CompanyKindBadge({ kind }: { kind: string }) {
  const { t } = useTranslation()

  return (
    <Badge variant={kind === 'company' ? 'outline' : 'secondary'}>
      {kind === 'company' ? t('admin.companies.kind.company') : t('admin.companies.kind.division')}
    </Badge>
  )
}
