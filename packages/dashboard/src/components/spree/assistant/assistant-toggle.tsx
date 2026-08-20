import { Button } from '@spree/dashboard-ui'
import { SparklesIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useAssistant } from './assistant-provider'

/**
 * Opens and closes the assistant column. Renders nothing unless this store has
 * a connected AI provider and this admin may use it — a button that only ever
 * explains why it cannot help is worse than no button.
 */
export function AssistantToggle() {
  const { t } = useTranslation()
  const { enabled, open, toggle } = useAssistant()

  if (!enabled) return null

  return (
    <Button
      variant={open ? 'outline' : 'ghost'}
      size="icon"
      aria-label={t('admin.assistant.title')}
      aria-pressed={open}
      title={t('admin.assistant.title')}
      onClick={toggle}
    >
      <SparklesIcon className="size-4" />
    </Button>
  )
}
