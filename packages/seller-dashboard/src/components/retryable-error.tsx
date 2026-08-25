import { Button } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { CenteredMessage } from './centered-message'

/**
 * Shown when a page's own query failed, in place of its content.
 *
 * Distinct from a "not found" message on purpose: a failed request and a
 * missing record send the seller looking for different causes, and only one
 * of the two is worth retrying.
 */
export function RetryableError({ onRetry }: { onRetry: () => void }) {
  const { t } = useTranslation()

  return (
    <CenteredMessage>
      {t('common.error')}{' '}
      <Button variant="outline" onClick={onRetry}>
        {t('common.retry')}
      </Button>
    </CenteredMessage>
  )
}
