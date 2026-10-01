module Spree
  module Emails
    # Finds the Liquid template behind an email key.
    #
    # With a store, an editable template (see Spree.editable_email_templates)
    # is looked up in the store first: its published version in the email's
    # language, then its version for every language. Otherwise, and for every
    # other template, the app's own file wins over the one a gem ships.
    # `drafts` puts unsaved templates in front of everything, for previews and
    # for checking a draft before it is published.
    class TemplateResolver
      KEY_FORMAT = %r{\A[a-z0-9_]+(?:/[a-z0-9_]+)*\z}

      class InvalidKey < ArgumentError; end

      # @param view_paths [Array<String, Pathname>] directories to search, highest precedence first
      # @param store [Spree::Store, nil] the store whose published templates apply
      # @param locale [String, Symbol, nil] the email's language
      # @param drafts [Hash{String => Spree::Emails::Template}] unsaved templates by key
      def initialize(view_paths, store: nil, locale: nil, drafts: {})
        @view_paths = view_paths.map(&:to_s).uniq
        @store = store
        @locale = locale.to_s
        @drafts = drafts
        @stored = {}
      end

      # @param key [String] e.g. "spree/order_mailer/confirm_email"
      # @return [Spree::Emails::Template, nil]
      def find(key)
        validate!(key)
        @drafts[key] || stored(key) || find_file(key, '.liquid')
      end

      # The default: what answers for the key without the store's templates or drafts.
      #
      # @param key [String]
      # @return [Spree::Emails::Template, nil]
      def find_default(key)
        validate!(key)
        Spree.editable_email_templates[key]&.kind == :partial ? partial_file(key) : find_file(key, '.liquid')
      end

      # A hand-written plain-text part. A store's saved template has none, so
      # its text is always generated from its HTML.
      #
      # @param key [String]
      # @return [Spree::Emails::Template, nil]
      def find_text(key)
        validate!(key)
        return if @drafts[key] || stored(key)

        find_file(key, '.text.liquid')
      end

      # @param name [String] a partial name, e.g. "spree/shared/line_item"
      # @return [Spree::Emails::Template, nil] the store's version, or "spree/shared/_line_item.liquid"
      def find_partial(name)
        validate!(name)
        @drafts[name] || stored(name) || partial_file(name)
      end

      private

      attr_reader :view_paths

      def stored(key)
        return unless @store && Spree.editable_email_templates.include?(key)
        return @stored[key] if @stored.key?(key)

        record = @store.email_templates.published.where(key: key, locale: [@locale, Spree::EmailTemplate::ANY_LOCALE]).
                 min_by { |template| template.locale == Spree::EmailTemplate::ANY_LOCALE ? 1 : 0 }
        @stored[key] = record && Template.new(key: key, subject: record.subject, body: record.body)
      end

      def partial_file(name)
        *folders, file = name.split('/')
        find_file([*folders, "_#{file}"].join('/'), '.liquid')
      end

      def find_file(key, extension)
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
