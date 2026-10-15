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
      # @param branding [Hash] unsaved branding values (see Spree::Emails::Branding)
      # @param mailer_logo_signed_id [String, nil] the signed id of an unsaved, uploaded email logo
      # @param mailer_logo_cleared [Boolean] whether the email logo is previewed as removed
      def initialize(store:, key:, locale: Spree::EmailTemplate::ANY_LOCALE, subject: nil, body: nil,
                     record_id: nil, email_key: nil, strict: false, branding: {}, mailer_logo_signed_id: nil,
                     mailer_logo_cleared: false)
        @store = store
        @key = key
        @locale = locale.presence || Spree::EmailTemplate::ANY_LOCALE
        @subject = subject
        @body = body
        @record_id = record_id
        @email_key = email_key
        @strict = strict
        @branding = branding
        @mailer_logo_signed_id = mailer_logo_signed_id
        @mailer_logo_cleared = mailer_logo_cleared
      end

      # @return [Spree::Emails::RenderedEmail]
      # @raise [Spree::EmailTemplates::NoSampleRecord] when the store has no record to build the sample from
      # @raise [ActiveRecord::RecordInvalid] when the unsaved logo is one saving the store would refuse
      # @raise [ActiveSupport::MessageVerifier::InvalidSignature] when the unsaved logo's signed id is not valid
      def call
        sample = email.sample_class.new(store: @store, record_id: @record_id)

        in_locale do
          renderer = Spree::Emails::Renderer.new(resolver: resolver, store: email_store, currency: sample.currency,
                                                 strict: @strict, branding: @branding)
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
                     emails = Spree.editable_email_templates.emails
                     emails.find { |candidate| candidate.key == @email_key } || emails.first
                   end
      end

      private

      def definition
        Spree.editable_email_templates[@key] || raise(ArgumentError, "#{@key} is not an editable email template")
      end

      # The store as the email shows it. An unsaved logo upload or removal is
      # applied to a copy that is never saved, and checked as saving the store
      # checks it, so the preview never shows a logo the Save button refuses.
      def email_store
        return @store if @mailer_logo_signed_id.nil? && !@mailer_logo_cleared

        @email_store ||= @store.class.find(@store.id).tap do |store|
          store.mailer_logo = @mailer_logo_cleared ? nil : @mailer_logo_signed_id
          store.validate
          (store.errors.attribute_names - [:mailer_logo]).each { |attribute| store.errors.delete(attribute) }
          raise ActiveRecord::RecordInvalid, store if store.errors.any?
        end
      end

      def resolver
        @resolver ||= Spree::Emails::TemplateResolver.for_mailers(store: @store, locale: language, drafts: drafts)
      end

      # An unsaved subject or body sent alone is previewed with the other half
      # customers currently get.
      def drafts
        return {} if @subject.nil? && @body.nil?

        current = Spree::Emails::TemplateResolver.for_mailers(store: @store, locale: language).find(@key)
        subject = @subject.nil? ? current&.subject : @subject
        body = @body.nil? ? current&.body : @body
        { @key => Spree::Emails::Template.new(key: @key, subject: subject, body: body) }
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
