import {
  Button,
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
} from '@spree/dashboard-ui'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { isSupportedVideoUrl } from '../../../lib/video-url'

interface Props {
  open: boolean
  onOpenChange: (open: boolean) => void
  onAdd: (url: string) => void
}

// Collects a YouTube or Vimeo link. The same check runs again on the server,
// so this is here to tell the merchant straight away rather than after a save.
export function AddVideoDialog({ open, onOpenChange, onAdd }: Props) {
  const { t } = useTranslation()
  const [url, setUrl] = useState('')
  const [touched, setTouched] = useState(false)

  const invalid = touched && url.trim().length > 0 && !isSupportedVideoUrl(url)

  const close = () => {
    setUrl('')
    setTouched(false)
    onOpenChange(false)
  }

  // This dialog renders inside the product form, so the submit must be stopped
  // here — letting it bubble would save the whole product.
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    event.stopPropagation()
    setTouched(true)
    if (!isSupportedVideoUrl(url)) return
    onAdd(url.trim())
    close()
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) close()
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.products.media.add_video_title')}</DialogTitle>
        </DialogHeader>

        <form onSubmit={submit}>
          <Field>
            <FieldLabel htmlFor="external-video-url">
              {t('admin.fields.media.external_video_url.label')}
            </FieldLabel>
            <Input
              id="external-video-url"
              value={url}
              autoFocus
              aria-invalid={invalid || undefined}
              placeholder={t('admin.fields.media.external_video_url.placeholder')}
              onChange={(e) => setUrl(e.target.value)}
              onBlur={() => setTouched(true)}
            />
            {invalid ? (
              <FieldError>{t('admin.products.media.video_url_invalid')}</FieldError>
            ) : (
              <p className="text-xs text-muted-foreground">
                {t('admin.fields.media.external_video_url.help')}
              </p>
            )}
          </Field>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={close}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={url.trim().length === 0}>
              {t('admin.products.media.add_video_submit')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
