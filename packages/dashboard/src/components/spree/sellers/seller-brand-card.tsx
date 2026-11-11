import type { Seller } from '@spree/admin-sdk'
import { signedIdParam } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  Field,
  FieldDescription,
  FieldError,
  FieldLabel,
  Input,
  RichTextEditor,
} from '@spree/dashboard-ui'
import { PencilIcon, StoreIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerValuesToParams } from '../../../schemas/seller'
import { ResourceImageField } from '../resource-image-field'
import { SellerInlineForm } from './seller-inline-form'

type Part = 'cover' | 'logo' | 'details'

/**
 * Cover photo, logo and the seller's own description — the storefront face.
 * Each has its own pencil: the images open a dialog and the description is
 * edited in place, so changing the cover never puts the description in front
 * of the operator.
 */
export function SellerBrandCard({ seller, canEdit }: { seller: Seller; canEdit: boolean }) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState<Part | null>(null)
  const done = () => setEditing(null)

  const editButton = (part: Part, label: string, className: string) =>
    canEdit && (
      <Button
        variant="ghost"
        size="icon-sm"
        className={className}
        onClick={() => setEditing(part)}
        aria-label={label}
        aria-expanded={editing === part}
      >
        <PencilIcon className="size-4" />
      </Button>
    )

  // Over an image, the button needs its own backdrop to stay legible.
  const overlay = 'bg-background/80 backdrop-blur-sm hover:bg-background'

  return (
    <Card className="overflow-hidden">
      {/* A seller with no cover gets a slim band rather than a tall empty
          block. It uses --accent rather than --muted: muted is a deliberate
          "whisper" against white, which over a region this size disappears
          entirely and leaves the logo looking unanchored. */}
      <div className="relative">
        {seller.cover_photo_url ? (
          <img src={seller.cover_photo_url} alt="" className="h-40 w-full bg-accent object-cover" />
        ) : (
          <div className="h-20 w-full border-border border-b bg-muted" />
        )}
        {editButton(
          'cover',
          t('admin.sellers.detail.edit_cover'),
          `absolute top-3 right-3 ${overlay}`,
        )}
      </div>

      {/* The logo straddles the band, so it needs more inset than CardContent's
          own padding gives — otherwise an 80px tile pulled up over a slim band
          reads as hanging off the card's corner. */}
      <CardContent className="flex flex-col gap-4 px-5 pb-5">
        {/* Positioned with its own z-index: the band above is `relative`, so a
            plain sibling paints underneath it and the band's edge cuts across
            the tile. The border belongs on the tile itself rather than a ring
            outside it, which over the band reads as a halo. */}
        <div className="-mt-10 relative z-10 w-fit">
          <div className="flex size-20 items-center justify-center overflow-hidden rounded-xl border border-border bg-card shadow-sm">
            {/* The square logo is the one cropped for a tile like this; the
                main logo is the fallback, since a seller may have set only one. */}
            {seller.square_logo_url || seller.logo_url ? (
              <img
                src={seller.square_logo_url ?? seller.logo_url ?? undefined}
                alt=""
                className="size-full object-cover"
              />
            ) : (
              <StoreIcon className="size-7 text-muted-foreground" />
            )}
          </div>
          {editButton(
            'logo',
            t('admin.sellers.detail.edit_logo'),
            `-right-3 -bottom-2 absolute border border-border shadow-sm ${overlay}`,
          )}
        </div>

        {editing === 'details' ? (
          <SellerInlineForm
            seller={seller}
            label={t('admin.sellers.detail.edit_profile')}
            toParams={(values) => {
              const params = sellerValuesToParams(values)
              return { name: params.name, slug: params.slug, about: params.about }
            }}
            onDone={done}
          >
            {(form) => {
              const { errors } = form.formState
              return (
                <>
                  <Field>
                    <FieldLabel htmlFor="seller-name">{t('admin.fields.name.label')}</FieldLabel>
                    <Input
                      id="seller-name"
                      aria-invalid={!!errors.name || undefined}
                      {...form.register('name')}
                    />
                    <FieldError errors={[errors.name]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="seller-slug">{t('admin.fields.slug.label')}</FieldLabel>
                    <Input
                      id="seller-slug"
                      aria-invalid={!!errors.slug || undefined}
                      {...form.register('slug')}
                    />
                    <FieldDescription>{t('admin.fields.seller.slug.help')}</FieldDescription>
                    <FieldError errors={[errors.slug]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="seller-about">
                      {t('admin.fields.seller.about.label')}
                    </FieldLabel>
                    <Controller
                      control={form.control}
                      name="about"
                      render={({ field }) => (
                        <RichTextEditor
                          id="seller-about"
                          ariaLabel={t('admin.fields.seller.about.label')}
                          value={field.value ?? ''}
                          onChange={field.onChange}
                        />
                      )}
                    />
                    <FieldDescription>{t('admin.fields.seller.about.help')}</FieldDescription>
                  </Field>
                </>
              )
            }}
          </SellerInlineForm>
        ) : (
          <>
            {/* The name already sits in the page header; repeating it here
                would just be the same words twice. The handle is what the
                header lacks. */}
            <div className="flex items-center justify-between gap-3">
              <p className="text-muted-foreground text-base">/{seller.slug}</p>
              {editButton('details', t('admin.sellers.detail.edit_profile'), '')}
            </div>

            {seller.about_html ? (
              // Server-sanitized on every write path (Spree::RichTextSanitizer),
              // which is what makes rendering it here safe.
              <div
                className="prose prose-sm max-w-none dark:prose-invert"
                // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized server-side
                dangerouslySetInnerHTML={{ __html: seller.about_html }}
              />
            ) : (
              <p className="text-muted-foreground text-base">
                {t('admin.sellers.detail.no_about')}
              </p>
            )}
          </>
        )}
      </CardContent>
      {/* Images get a dialog: an upload with its preview needs more room than
          the card gives, and the card keeps showing what is saved meanwhile. */}
      {editing === 'cover' && (
        <SellerInlineForm
          seller={seller}
          label={t('admin.sellers.detail.edit_cover')}
          toParams={(values) =>
            signedIdParam('cover_photo', values.cover_photo_signed_id, values.cover_photo_cleared)
          }
          onDone={done}
          dialog={{ title: t('admin.sellers.detail.edit_cover') }}
        >
          {(form) => (
            <ResourceImageField
              form={form}
              kind="cover_photo"
              serverUrl={seller.cover_photo_url}
              translationNamespace="admin.sellers"
              labelKey="cover_photo_label"
              helpKey="cover_photo_help"
            />
          )}
        </SellerInlineForm>
      )}
      {editing === 'logo' && (
        <SellerInlineForm
          seller={seller}
          label={t('admin.sellers.detail.edit_logo')}
          toParams={(values) => ({
            ...signedIdParam('logo', values.logo_signed_id, values.logo_cleared),
            ...signedIdParam(
              'square_logo',
              values.square_logo_signed_id,
              values.square_logo_cleared,
            ),
          })}
          onDone={done}
          dialog={{ title: t('admin.sellers.detail.edit_logo') }}
        >
          {(form) => (
            <>
              <ResourceImageField
                form={form}
                kind="logo"
                serverUrl={seller.logo_url}
                square
                translationNamespace="admin.sellers"
                labelKey="logo_label"
                helpKey="logo_help"
              />
              <ResourceImageField
                form={form}
                kind="square_logo"
                serverUrl={seller.square_logo_url}
                square
                translationNamespace="admin.sellers"
                labelKey="square_logo_label"
                helpKey="square_logo_help"
              />
            </>
          )}
        </SellerInlineForm>
      )}
    </Card>
  )
}
