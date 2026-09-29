module Spree
  class BaseMailer < ActionMailer::Base
    default from: -> { from_address }, reply_to: -> { reply_to_address }

    def current_store
      @current_store ||= @order&.store.presence || Spree::Store.current || Spree::Store.default
    end

    helper_method :current_store

    # Render an email in the given locale, with the store's translation fallbacks
    # active, and restore both afterwards. Controllers set these fallbacks per
    # request via `set_fallback_locale`, but mailers run in background jobs where
    # that never happens — so without this, translatable attributes (store name,
    # product names, taxon names, …) return nil under a non-default locale and
    # leave e.g. the footer blank. Setting the fallbacks here mirrors a request,
    # so reads fall back to the store's default-locale value.
    #
    # @param store [Spree::Store]
    # @param locale [String, Symbol, nil] defaults to the store's default locale
    def with_store_locale(store, locale = nil, &block)
      locale = locale.presence || store&.default_locale
      return yield if locale.blank?

      previous_fallbacks = Mobility.store_based_fallbacks
      previously_active = @_store_locale_active
      @_store_locale_active = true
      begin
        Spree::Locales::SetFallbackLocaleForStore.new.call(store: store) if store
        I18n.with_locale(locale, &block)
      ensure
        @_store_locale_active = previously_active
        Mobility.store_based_fallbacks = previous_fallbacks
      end
    end

    def from_address
      current_store.mail_from_address
    end

    def reply_to_address
      current_store.support_email_address
    end

    def money(amount, currency = nil)
      currency ||= current_store.default_currency
      Spree::Money.new(amount, currency: currency).to_s
    end
    helper_method :money

    def mail(headers = {}, &block)
      ensure_default_action_mailer_url_host(headers[:store_url])
      Spree::Emails::LegacyTemplates.warn_unstyled(self) unless @_rendering_template || self.class._layout

      if @_store_locale_active
        super
      else
        # Subclasses that call `mail` without wrapping their action in
        # `with_store_locale` (e.g. extension mailers) still get the
        # store default locale, as `mail` applied before Spree 5.6.
        with_store_locale(current_store) { super }
      end
    end

    protected

    # Renders the current action's email from its Liquid template and builds
    # the message. The template's front matter supplies the subject, and the
    # plain-text part is generated from the HTML unless a `.text.liquid` sits
    # next to the template.
    #
    # @param assigns [Hash] the template's variables — serializer output and
    #   mailer-built values such as token-carrying URLs, never models
    # @param template [String] the template key, defaults to the action's view path
    # @param headers [Hash] mail headers (`to:`, `store_url:`, ...)
    # @return [Mail::Message]
    def mail_template(assigns = {}, template: "#{mailer_name}/#{action_name}", **headers)
      @_rendering_template = true
      in_store_locale do
        resolver = Spree::Emails::TemplateResolver.new(self.class.view_paths.paths.map(&:path))
        email_template = resolver.find(template) || raise(ArgumentError, "Missing email template #{template}.liquid")
        renderer = Spree::Emails::Renderer.new(resolver: resolver, store: current_store, currency: email_currency)

        if email_template.erb?
          liquid_template = resolver.find_liquid(template)
          subject = liquid_template ? renderer.render_subject(liquid_template, assigns) : headers[:subject]
          mail_legacy_template(email_template, subject, headers)
        else
          email = renderer.render(email_template, assigns)

          mail(headers.merge(subject: email.subject)) do |format|
            format.text { render plain: email.text, layout: false }
            format.html { render html: email.html.html_safe, layout: false }
          end
        end
      end
    ensure
      @_rendering_template = false
    end

    # The currency an email's amounts are in: its order's, else the store's.
    #
    # @return [String]
    def email_currency
      (@order || @order_group)&.currency || current_store.default_currency
    end

    # A record as its template reads it: the serializer's JSON, the same data
    # a renderer outside Ruby would receive. Download links and other bearer
    # tokens stay out; the mailer builds any URL that carries one.
    #
    # @param object [Object, nil] the record
    # @param serializer [Class] an email serializer
    # @param params [Hash] serializer params, over the email's store, currency and locale
    # @return [Hash, nil]
    def email_data(object, serializer, **params)
      return if object.nil?

      params = { store: current_store, currency: email_currency, locale: I18n.locale.to_s,
                 storefront_url: current_store.storefront_url.to_s.chomp('/'),
                 hide_credentials: true }.merge(params)
      JSON.parse(serializer.new(object, params: params).serialize)
    end

    # URI-based merge preserves existing query params and fragments so the token
    # doesn't get swallowed by a `#section` or clobber an existing `?source=`.
    def append_token(url, token)
      uri = URI.parse(url.to_s)
      params = URI.decode_www_form(uri.query || '')
      params << ['token', token.to_s]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    rescue URI::InvalidURIError
      separator = url.include?('?') ? '&' : '?'
      "#{url}#{separator}token=#{CGI.escape(token.to_s)}"
    end

    private

    def in_store_locale(&block)
      @_store_locale_active ? yield : with_store_locale(current_store, &block)
    end

    # An ERB view at the email's path: the host app's own override, or the
    # `spree_legacy_emails` gem. Rendered the way every email was before 6.0.
    def mail_legacy_template(template, subject, headers)
      Spree::Emails::LegacyTemplates.warn_rendered(template)

      mail(headers.merge(subject: subject, template_path: File.dirname(template.key),
                         template_name: File.basename(template.key)))
    end

    # this ensures that ActionMailer::Base.default_url_options[:host] is always set
    # this is only a fail-safe solution if developer didn't set this in environment files
    # http://guides.rubyonrails.org/action_mailer_basics.html#generating-urls-in-action-mailer-views
    def ensure_default_action_mailer_url_host(store_url = nil)
      host_url = store_url.presence || current_store.try(:storefront_url)

      return if host_url.blank?

      ActionMailer::Base.default_url_options ||= {}
      ActionMailer::Base.default_url_options[:host] = host_url
    end
  end
end
