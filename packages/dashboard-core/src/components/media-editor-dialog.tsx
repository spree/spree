import {
  Button,
  cn,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from '@spree/dashboard-ui'
import { ArrowLeftIcon } from '@spree/dashboard-ui/icons'
import type { FormEvent, ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

export interface MediaEditorDialogProps {
  open: boolean
  /** Closing goes through here — Escape, the back button — so a host can ask first. */
  onOpenChange: (open: boolean) => void
  title: ReactNode
  /** Read by screen readers as the editor's description. */
  description?: ReactNode
  /** The top bar's end: Cancel / Save, Discard / Done. */
  actions?: ReactNode
  /** The file itself, centred on the stage — usually a `MediaPreview` with `fit="stage"`. */
  preview: ReactNode
  /** A pill floating under the picture, such as the focal point hint. */
  hint?: ReactNode
  /** Makes the editor a form, so Enter in a field and a submit button in `actions` save. */
  onSubmit?: (event: FormEvent<HTMLFormElement>) => void
  /** The side panel's sections — `MediaEditorSection`s. */
  children: ReactNode
}

/**
 * A full-screen editor for one media file: a top bar with the way out, the
 * file's name and its save actions; the file on a dark stage, as large as the
 * window allows; and a panel of sections beside it.
 *
 * Always dark, whatever the admin's theme — a picture is judged against a
 * neutral ground, the way photo tools show it. Headless about saving: each
 * host keeps its own model (the product form's Done, the library's Save).
 */
export function MediaEditorDialog({
  open,
  onOpenChange,
  title,
  description,
  actions,
  preview,
  hint,
  onSubmit,
  children,
}: MediaEditorDialogProps) {
  const { t } = useTranslation()

  const layout = (
    <>
      <header className="flex h-14 shrink-0 items-center gap-2 border-b border-border px-3">
        <Button
          type="button"
          variant="ghost"
          size="icon-sm"
          onClick={() => onOpenChange(false)}
          aria-label={t('admin.actions.close')}
        >
          <ArrowLeftIcon className="size-4 rtl:rotate-180" />
        </Button>
        <DialogTitle className="min-w-0 truncate font-medium text-base">{title}</DialogTitle>
        {description && <DialogDescription className="sr-only">{description}</DialogDescription>}
        <div className="ms-auto flex shrink-0 items-center gap-2">{actions}</div>
      </header>

      <div className="flex min-h-0 flex-1 flex-col overflow-y-auto md:flex-row md:overflow-hidden">
        {/* A faint dot grid, so the edge of a picture with a dark or
            transparent background still reads against the stage. */}
        <div className="relative flex min-h-[50vh] flex-1 items-center justify-center bg-[radial-gradient(circle,oklch(1_0_0/0.07)_1px,transparent_1px)] bg-size-[20px_20px] p-6 pb-20 md:min-h-0 md:p-10 md:pb-20">
          {preview}
          {hint && (
            <div className="absolute bottom-5 left-1/2 flex max-w-[calc(100%-2rem)] -translate-x-1/2 items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-base shadow-lg">
              {hint}
            </div>
          )}
        </div>

        <aside className="flex w-full shrink-0 flex-col gap-3 border-border border-t p-3 md:w-80 md:overflow-y-auto md:border-t-0 md:border-s">
          {children}
        </aside>
      </div>
    </>
  )

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        fullScreen
        showCloseButton={false}
        // Edge to edge, and a dark scope for everything inside it.
        className="dark inset-0 gap-0 rounded-none border-0 bg-background p-0 text-foreground"
      >
        {onSubmit ? (
          <form onSubmit={onSubmit} className="flex min-h-0 flex-1 flex-col">
            {layout}
          </form>
        ) : (
          layout
        )}
      </DialogContent>
    </Dialog>
  )
}

/** One card of the editor's side panel. */
export function MediaEditorSection({
  icon,
  title,
  children,
  className,
}: {
  icon?: ReactNode
  title: ReactNode
  children: ReactNode
  className?: string
}) {
  return (
    <section className={cn('flex flex-col gap-4 rounded-xl bg-card p-4', className)}>
      <h3 className="flex items-center gap-2 font-medium text-base [&_svg]:size-4 [&_svg]:text-muted-foreground">
        {icon}
        {title}
      </h3>
      {children}
    </section>
  )
}
