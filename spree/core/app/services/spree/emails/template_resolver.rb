module Spree
  module Emails
    # Finds the Liquid template behind an email key, across the app's view
    # paths: the host app's own file first, then the first one a gem ships.
    # A later database step slots in front of this without changing any mailer.
    class TemplateResolver
      KEY_FORMAT = %r{\A[a-z0-9_]+(?:/[a-z0-9_]+)*\z}

      class InvalidKey < ArgumentError; end

      # @param view_paths [Array<String, Pathname>] directories to search, highest precedence first
      def initialize(view_paths)
        @view_paths = view_paths.map(&:to_s).uniq
      end

      # @param key [String] e.g. "spree/order_mailer/confirm_email"
      # @return [Spree::Emails::Template, nil]
      def find(key)
        find_file(key, '.liquid')
      end

      # @param key [String]
      # @return [Spree::Emails::Template, nil] the hand-written plain-text part, when there is one
      def find_text(key)
        find_file(key, '.text.liquid')
      end

      # @param name [String] a partial name, e.g. "spree/shared/line_item"
      # @return [String, nil] the partial's path, "spree/shared/_line_item.liquid"
      def find_partial(name)
        validate!(name)
        *folders, file = name.split('/')
        find_file([*folders, "_#{file}"].join('/'), '.liquid')&.path
      end

      private

      attr_reader :view_paths

      def find_file(key, extension)
        validate!(key)

        view_paths.each do |view_path|
          path = File.join(view_path, "#{key}#{extension}")
          return Template.new(key: key, path: path) if File.file?(path)
        end

        nil
      end

      def validate!(key)
        raise InvalidKey, "Invalid email template name: #{key.inspect}" unless key.to_s.match?(KEY_FORMAT)
      end
    end
  end
end
