# frozen_string_literal: true

module Spree
  module Admin
    # Helpers for the product Publishing card in the Rails admin. Mirrors the
    # SPA's publishing card (see packages/dashboard/src/components/spree/products/publishing-card.tsx):
    # per-channel status is gated by product status — Draft/Archived products
    # render every publication as +not_available+ regardless of window.
    module PublishingHelper
      # @param product_status [String] the product's status (draft/active/archived)
      # @param publication [Spree::ProductPublication]
      # @return [Symbol] one of :live, :scheduled, :hidden, :not_available
      def publication_schedule_status(product_status, publication)
        return :not_available unless product_status == 'active'

        now = Time.current
        return :hidden if publication.unpublished_at && publication.unpublished_at <= now
        return :scheduled if publication.published_at && publication.published_at > now

        :live
      end

      # Renders a colored dot + status label for a publication row.
      def publication_status_badge(product_status, publication)
        status = publication_schedule_status(product_status, publication)
        dot_class = case status
                    when :live then 'bg-success'
                    when :scheduled then 'bg-warning'
                    else 'bg-secondary'
                    end

        label = Spree.t("admin.publishing.status_#{status}")

        content_tag(:span, class: 'd-inline-flex align-items-center gap-1 text-muted small') do
          content_tag(:span, '', class: "publication-dot rounded-circle #{dot_class}",
                                 style: 'display:inline-block; width:0.5rem; height:0.5rem;') +
            content_tag(:span, label)
        end
      end

      # One-line summary of the publication window in the store's timezone.
      def publication_caption(product_status, publication, store)
        status = publication_schedule_status(product_status, publication)
        tz = ActiveSupport::TimeZone[store.preferred_timezone] || Time.zone

        case status
        when :not_available
          Spree.t('admin.publishing.caption_not_available',
                  product_status: Spree.t("admin.products.status_options.#{product_status}", default: product_status.to_s.humanize))
        when :hidden
          Spree.t('admin.publishing.caption_unpublished',
                  date: l(publication.unpublished_at.in_time_zone(tz), format: :short))
        when :scheduled
          if publication.unpublished_at
            Spree.t('admin.publishing.caption_window',
                    start: l(publication.published_at.in_time_zone(tz), format: :short),
                    end:   l(publication.unpublished_at.in_time_zone(tz), format: :short))
          else
            Spree.t('admin.publishing.caption_scheduled',
                    date: l(publication.published_at.in_time_zone(tz), format: :short))
          end
        else # :live
          if publication.unpublished_at
            Spree.t('admin.publishing.caption_hidden_after',
                    date: l(publication.unpublished_at.in_time_zone(tz), format: :short))
          else
            Spree.t('admin.publishing.caption_live')
          end
        end
      end
    end
  end
end
