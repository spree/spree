module Spree
  module Emails
    # Finds the file behind an email key, across the app's view paths.
    #
    # Lookup order: the host app's `.liquid`, then — only while the
    # `spree_legacy_emails` gem is installed — an ERB view at the key's path
    # (the host app's or that gem's; removed in 6.1), then the first `.liquid`
    # a gem ships. A later
    # database step slots in front of this chain without changing any mailer.
    class TemplateResolver
      KEY_FORMAT = %r{\A[a-z0-9_]+(?:/[a-z0-9_]+)*\z}

      class InvalidKey < ArgumentError; end

      # @param view_paths [Array<String, Pathname>] directories to search, highest precedence first
      # @param app_view_path [String, Pathname, nil] the host application's own view directory
      # @param legacy [Boolean] whether ERB views are looked up at all
      def initialize(view_paths, app_view_path: Rails.root&.join('app/views'), legacy: Spree::Emails::LegacyTemplates.enabled?)
        @view_paths = view_paths.map(&:to_s).uniq
        @app_view_path = app_view_path&.to_s
        @legacy = legacy
      end

      # @param key [String]
      # @return [Spree::Emails::Template, nil]
      def find(key)
        validate!(key)

        app_liquid(key) || (@legacy && find_file(key, '.html.erb')) || find_liquid(key)
      end

      # The Liquid template only, skipping ERB views.
      #
      # @param key [String]
      # @return [Spree::Emails::Template, nil]
      def find_liquid(key)
        validate!(key)
        find_file(key, '.liquid')
      end

      # @param key [String]
      # @return [Spree::Emails::Template, nil] the hand-written plain-text part, when there is one
      def find_text(key)
        validate!(key)
        find_file(key, '.text.liquid')
      end

      # @param name [String] a partial name, e.g. "spree/shared/line_item"
      # @return [String, nil] the partial's path, "spree/shared/_line_item.liquid"
      def find_partial(name)
        validate!(name)
        find_file(File.join(File.dirname(name), "_#{File.basename(name)}"), '.liquid')&.path
      end

      private

      attr_reader :view_paths, :app_view_path

      def app_liquid(key)
        return if app_view_path.blank?

        path = File.join(app_view_path, "#{key}.liquid")
        Template.new(key: key, path: path) if File.file?(path)
      end

      def find_file(key, extension)
        view_paths.each do |view_path|
          path = File.join(view_path, "#{key}#{extension}")
          return Template.new(key: key.delete_prefix('/'), path: path) if File.file?(path)
        end

        nil
      end

      def validate!(key)
        raise InvalidKey, "Invalid email template name: #{key.inspect}" unless key.to_s.match?(KEY_FORMAT)
      end
    end
  end
end
