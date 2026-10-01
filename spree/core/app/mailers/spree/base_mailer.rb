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
      # Mailers that don't wrap their action in `with_store_locale` still get
      # the store's default locale, as `mail` applied before Spree 5.6.
      in_store_locale { super }
    end

    protected

    # Locale for an email to a staff member or seller: their own dashboard
    # language, then the store's admin locale, then nil — which lets
    # with_store_locale fall back to the store's default. Blank or unavailable
    # values fall through.
    def staff_locale(user, store)
      [user.try(:selected_locale), store&.preferred_admin_locale].find { |locale| I18n.locale_available?(locale) }
    end

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
        email = render_email_template(template, assigns)

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
      Spree::Emails::TemplateData.call(object, serializer, store: current_store, currency: email_currency, **params)
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

    # A store's published template passed its checks with sample data, but a
    # real record can still trip it. The customer then gets the email from the
    # files rather than none, and the error is reported.
    def render_email_template(template, assigns)
      resolver = email_resolver(template)
      email_renderer(resolver).render(find_email_template(resolver, template), assigns)
    rescue Liquid::Error, MRML::Error => e
      raise unless resolver&.store

      Rails.error.report(e, context: { email_template: template, store_id: current_store&.id })
      fallback = email_resolver
      email_renderer(fallback).render(find_email_template(fallback, template), assigns)
    end

    def find_email_template(resolver, template)
      resolver.find(template) || raise(ArgumentError, "Missing email template #{template}.liquid")
    end

    # The store's published templates apply only to the emails merchants may
    # edit; every other email, and the layout and partials it uses, comes
    # from files.
    def email_resolver(template = nil)
      view_paths = self.class.view_paths.paths.map(&:path)
      return Spree::Emails::TemplateResolver.new(view_paths) unless Spree.editable_email_templates.include?(template)

      Spree::Emails::TemplateResolver.new(view_paths, store: current_store, locale: I18n.locale)
    end

    def email_renderer(resolver = email_resolver)
      Spree::Emails::Renderer.new(resolver: resolver, store: current_store, currency: email_currency)
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
