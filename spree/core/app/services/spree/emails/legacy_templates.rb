module Spree
  module Emails
    # The ERB email bridge for 6.0. The `spree_legacy_emails` gem ships the
    # pre-6.0 ERB emails and switches ERB lookup on; without it Spree renders
    # only Liquid and reports the host app's ERB overrides it now ignores.
    # Removed in 6.1 together with that gem.
    module LegacyTemplates
      # The ERB layout and shared partials the pre-6.0 emails were built from.
      LEGACY_VIEWS = %w[
        layouts/spree/base_mailer.html.erb
        spree/shared/_base_mailer_footer.html.erb
        spree/shared/_base_mailer_header.html.erb
        spree/shared/_base_mailer_stylesheets.html.erb
        spree/shared/_mailer_button.html.erb
        spree/shared/_mailer_hero.html.erb
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
        # @return [Boolean] whether the spree_legacy_emails gem is installed
        def enabled?
          defined?(SpreeLegacyEmails::Engine).present?
        end

        # @param template [Spree::Emails::Template] the ERB view being rendered
        def warn_rendered(template)
          warn_once(template.key,
                    "The email #{template.key} is rendered from the ERB view #{template.path}. ERB emails are " \
                    "deprecated and are removed together with the spree_legacy_emails gem in Spree 6.1. " \
                    "Port it to #{template.key}.liquid.")
        end

        # A mailer calling `mail` with its own ERB views no longer gets Spree's
        # email layout, which moved to spree_legacy_emails.
        #
        # @param mailer [Spree::BaseMailer]
        def warn_unstyled(mailer)
          return if enabled?

          key = "#{mailer.mailer_name}/#{mailer.action_name}"
          warn_once(key,
                    "#{mailer.class.name}##{mailer.action_name} renders its own views with `mail`, which no longer " \
                    "wraps them in Spree's email layout. Render it with `mail_template` and a Liquid template, or " \
                    "add the spree_legacy_emails gem to keep the ERB layout until Spree 6.1.")
        end

        # @param app_view_path [Pathname, String]
        # @param gem_view_paths [Array<Pathname, String>] where Spree's own Liquid templates live
        # @return [Array<String>] the host app's ERB overrides of Spree emails that are no longer rendered
        def ignored_overrides(app_view_path = Rails.root.join('app/views'), gem_view_paths = spree_view_paths)
          return [] if enabled?

          candidates = LEGACY_VIEWS + shipped_email_keys(gem_view_paths).flat_map { |key| ["#{key}.html.erb", "#{key}.text.erb"] }
          candidates.select { |file| File.file?(File.join(app_view_path.to_s, file)) }.sort
        end

        def warn_ignored_overrides
          files = ignored_overrides
          return if files.empty?

          Rails.logger.warn(
            "[Spree] Emails render from Liquid templates since Spree 6.0, so these ERB views in app/views are " \
            "ignored: #{files.join(', ')}. Port each to a .liquid file at the same path, or add the " \
            "spree_legacy_emails gem to keep rendering them until Spree 6.1."
          )
        end

        private

        def warn_once(key, message)
          @warned ||= Concurrent::Set.new
          Spree::Deprecation.warn(message) if @warned.add?(key)
        end

        def spree_view_paths
          engines = [Spree::Core::Engine]
          engines << Spree::Emails::Engine if defined?(Spree::Emails::Engine)
          engines.map { |engine| engine.root.join('app/views') }
        end

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
