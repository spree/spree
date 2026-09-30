module Spree
  module Emails
    # Spree's emails render from Liquid since 6.0, so an app's ERB override of
    # one of them is no longer used. Listed at boot so an upgrade does not
    # silently fall back to the default design.
    module ErbOverrides
      # The ERB partials the pre-6.0 emails were built from and no mailer reads now.
      REMOVED_PARTIALS = %w[
        spree/shared/_base_mailer_footer.html.erb
        spree/shared/_base_mailer_header.html.erb
        spree/shared/_base_mailer_stylesheets.html.erb
        spree/shared/_mailer_logo.html.erb
        spree/shared/_purchased_items_styles.html.erb
        spree/shared/_fulfillment_group_section.html.erb
        spree/shared/_fulfillment_group_section.text.erb
        spree/shared/_item_thumbnail_link.html.erb
        spree/shared/_order_summary_section.html.erb
        spree/shared/_po_number.text.erb
        spree/shared/_purchase_totals.html.erb
        spree/shared/_purchase_totals.text.erb
        spree/shared/_purchased_items_table.html.erb
        spree/shared/_purchased_items_table.text.erb
      ].freeze

      class << self
        # @param app_view_path [Pathname, String]
        # @param gem_view_paths [Array<Pathname, String>] where Spree's own Liquid templates live
        # @return [Array<String>] the app's ERB overrides of Spree emails that are no longer used
        def ignored(app_view_path = Rails.root.join('app/views'), gem_view_paths = Spree::BaseMailer.view_paths.paths.map(&:path))
          return [] unless File.directory?(File.join(app_view_path.to_s, 'spree'))

          candidates = REMOVED_PARTIALS + shipped_email_keys(gem_view_paths).flat_map { |key| ["#{key}.html.erb", "#{key}.text.erb"] }
          candidates.select { |file| File.file?(File.join(app_view_path.to_s, file)) }.sort
        end

        def warn
          files = ignored
          return if files.empty?

          Rails.logger.warn(
            "[Spree] Emails render from Liquid templates since Spree 6.0, so these ERB views in app/views are " \
            "no longer used: #{files.join(', ')}. Port each email to a .liquid file at the same path."
          )
        end

        private

        def shipped_email_keys(view_paths)
          view_paths.flat_map do |view_path|
            Dir.glob(File.join(view_path.to_s, 'spree/*_mailer/*.liquid')).
              map { |path| path.delete_prefix("#{view_path}/").sub(/(\.text)?\.liquid\z/, '') }
          end.uniq
        end
      end
    end
  end
end
