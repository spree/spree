import type { Seller } from '@spree/admin-sdk'
import { Button, Card, CardContent } from '@spree/dashboard-ui'
import { PencilIcon, StoreIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

/** Cover photo, logo and the seller's own description — the storefront face. */
export function SellerBrandCard({
  seller,
  canEdit,
  onEdit,
}: {
  seller: Seller
  canEdit: boolean
  onEdit: () => void
}) {
  const { t } = useTranslation()

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
        {canEdit && (
          <Button
            variant="ghost"
            size="icon-sm"
            className="absolute top-3 right-3 bg-background/80 backdrop-blur-sm hover:bg-background"
            onClick={onEdit}
            aria-label={t('admin.actions.edit')}
          >
            <PencilIcon className="size-4" />
          </Button>
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
        <div className="-mt-10 relative z-10 flex size-20 items-center justify-center overflow-hidden rounded-xl border border-border bg-card shadow-sm">
          {/* The square logo is the one cropped for a tile like this; the main
              logo is the fallback, since a seller may have set only one. */}
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

        {/* The name already sits in the page header; repeating it here would
            just be the same words twice. The handle is what the header lacks. */}
        <p className="text-muted-foreground text-sm">/{seller.slug}</p>

        {seller.about_html ? (
          // Server-sanitized on every write path (Spree::RichTextSanitizer),
          // which is what makes rendering it here safe.
          <div
            className="prose prose-sm max-w-none dark:prose-invert"
            // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized server-side
            dangerouslySetInnerHTML={{ __html: seller.about_html }}
          />
        ) : (
          <p className="text-muted-foreground text-sm">{t('admin.sellers.detail.no_about')}</p>
        )}
      </CardContent>
    </Card>
  )
}
