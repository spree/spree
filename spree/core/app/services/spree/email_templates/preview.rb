module Spree
  module EmailTemplates
    # Renders an editable email template with sample data, through the same
    # renderer customers' emails go through. An unsaved subject and body take
    # the place of the store's published version; everything else the email
    # uses comes from the store's published templates and the files.
    #
    # The layout and shared partials are previewed inside an email that uses
    # them, the first editable email unless another is named.
    class Preview
      # @return [Hash] the variables the email was rendered with, once {#call} has run
      attr_reader :variables

      # @return [Spree::Emails::RenderedEmail, nil] the rendered email, once {#call} has run
      attr_reader :rendered

      # @param store [Spree::Store]
      # @param key [String] the editable template being previewed
      # @param locale [String] a language code, or "any"
      # @param subject [String, nil] an unsaved subject; nil keeps the current one
      # @param body [String, nil] an unsaved body; nil keeps the current one
      # @param record_id [String, nil] the prefixed id of the record to build sample data from
      # @param email_key [String, nil] for the layout or a partial, the email to show it in
      # @param strict [Boolean] whether an unknown variable raises
      def initialize(store:, key:, locale: Spree::EmailTemplate::ANY_LOCALE, subject: nil, body: nil,
                     record_id: nil, email_key: nil, strict: false)
        @store = store
        @key = key
        @locale = locale.presence || Spree::EmailTemplate::ANY_LOCALE
        @subject = subject
        @body = body
        @record_id = record_id
        @email_key = email_key
        @strict = strict
      end

      # @return [Spree::Emails::RenderedEmail]
      # @raise [Spree::EmailTemplates::NoSampleRecord] when the store has no record to build the sample from
      def call
        sample = email.sample_class.new(store: @store, record_id: @record_id)

        in_locale do
          renderer = Spree::Emails::Renderer.new(resolver: resolver, store: @store, currency: sample.currency, strict: @strict)
          sample_variables = sample.variables
          @variables = renderer.variables(sample_variables)
          @rendered = renderer.render(resolver.find(email.key), sample_variables)
        end
      end

      # @return [Spree::Emails::EditableTemplates::Definition] the email the preview renders
      def email
        @email ||= if definition.email?
                     definition
                   else
                     Spree.editable_email_templates[@email_key.to_s].then { |named| named&.email? ? named : nil } ||
                       Spree.editable_email_templates.emails.first
                   end
      end

      private

      def definition
        Spree.editable_email_templates[@key] || raise(ArgumentError, "#{@key} is not an editable email template")
      end

      def resolver
        @resolver ||= Spree::Emails::TemplateResolver.new(
          Spree::BaseMailer.view_paths.paths.map(&:path), store: @store, locale: language, drafts: drafts
        )
      end

      def drafts
        return {} if @body.nil?

        { @key => Spree::Emails::Template.new(key: @key, subject: @subject, body: @body) }
      end

      def language
        @locale == Spree::EmailTemplate::ANY_LOCALE ? @store.default_locale : @locale
      end

      # Mirrors how mailers render: the email's language with the store's
      # translation fallbacks, restored afterwards.
      def in_locale(&block)
        previous_fallbacks = Mobility.store_based_fallbacks
        Spree::Locales::SetFallbackLocaleForStore.new.call(store: @store)
        I18n.with_locale(language.presence || I18n.default_locale, &block)
      ensure
        Mobility.store_based_fallbacks = previous_fallbacks
      end
    end
  end
end
