import { ImportWizardDialog as SharedImportWizardDialog } from '@spree/dashboard-core'
import { useNavigate } from '@tanstack/react-router'
import { importTypeIndexPath } from '../../../lib/import-types'

interface ImportWizardDialogProps {
  /** Prefixed id of the import to drive; `null` keeps the dialog closed. */
  importId: string | null
  onClose: () => void
}

/**
 * The shared import wizard, pointed at this dashboard's routes.
 *
 * The wizard itself lives in `@spree/dashboard-core` so the seller panel
 * renders the same one. All this adds is where "View records" goes, which is
 * the single thing that cannot be shared: the two panels file their catalogs
 * under different route trees.
 */
export function ImportWizardDialog({ importId, onClose }: ImportWizardDialogProps) {
  const navigate = useNavigate()

  return (
    <SharedImportWizardDialog
      importId={importId}
      onClose={onClose}
      onViewRecords={(type) => navigate({ to: importTypeIndexPath(type) })}
    />
  )
}
