module Spree
  class BaseMailer < ActionMailer::Base
    helper Spree::ImagesHelper

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

    # Wraps HTML a mailer rendered from its own ERB views in the Liquid email
    # layout, so every email a Spree mailer sends carries the store's logo,
    # header and footer. Called by `layouts/spree/base_mailer.html.erb`.
    #
    # @param html [String] the rendered view
    # @return [ActiveSupport::SafeBuffer]
    def render_in_email_layout(html)
      email_renderer.wrap(html, subject: message.subject).html_safe
    end
    helper_method :render_in_email_layout

    def mail(headers = {}, &block)
      ensure_default_action_mailer_url_host(headers[:store_url])

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
      in_store_locale do
        email_template = email_resolver.find(template) || raise(ArgumentError, "Missing email template #{template}.liquid")
        email = email_renderer.render(email_template, assigns)

        mail(headers.merge(subject: email.subject)) do |format|
          format.text { render plain: email.text, layout: false }
          format.html { render html: email.html.html_safe, layout: false }
        end
      end
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

    def email_resolver
      @email_resolver ||= Spree::Emails::TemplateResolver.new(self.class.view_paths.paths.map(&:path))
    end

    def email_renderer
      Spree::Emails::Renderer.new(resolver: email_resolver, store: current_store, currency: email_currency)
    end

    def in_store_locale(&block)
      @_store_locale_active ? yield : with_store_locale(current_store, &block)
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
