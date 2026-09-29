module Spree
  module Emails
    # The ERB email bridge for 6.0. The `spree_legacy_emails` gem ships the
    # pre-6.0 ERB emails and switches ERB lookup on; without it Spree renders
    # only Liquid and reports the host app's ERB email files it now ignores.
    # Removed in 6.1 together with that gem.
    module LegacyTemplates
      EMAIL_VIEWS = %w[
        layouts/spree/base_mailer.html.erb
        spree/*_mailer/*.erb
        spree/shared/*.erb
        spree/shared/purchased_items_table/*.erb
      ].freeze

      class << self
        # @return [Boolean] whether the spree_legacy_emails gem is installed
        def enabled?
          defined?(SpreeLegacyEmails::Engine).present?
        end

        # @param template [Spree::Emails::Template] the ERB view being rendered
        def warn_rendered(template)
          @warned ||= Concurrent::Set.new
          return unless @warned.add?(template.key)

          Spree::Deprecation.warn(
            "The email #{template.key} is rendered from the ERB view #{template.path}. ERB emails are deprecated " \
            "and are removed together with the spree_legacy_emails gem in Spree 6.1. " \
            "Port it to #{template.key}.liquid."
          )
        end

        # @param app_view_path [Pathname, String]
        # @return [Array<String>] the host app's ERB email views Spree no longer renders
        def ignored_overrides(app_view_path = Rails.root.join('app/views'))
          return [] if enabled?

          EMAIL_VIEWS.flat_map { |pattern| Dir.glob(File.join(app_view_path.to_s, pattern)) }.
            map { |path| path.delete_prefix("#{app_view_path}/") }.uniq.sort
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
      end
    end
  end
end
