module Spree
  class BaseMailer < ActionMailer::Base
    helper Spree::ImagesHelper

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
      current_store.mail_from_address
    end

    def money(amount, currency = nil)
      currency ||= current_store.default_currency
      Spree::Money.new(amount, currency: currency).to_s
    end
    helper_method :money

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end
    helper_method :frontend_available?

    def mail(headers = {}, &block)
      ensure_default_action_mailer_url_host(headers[:store_url])
      return unless Spree::Config[:send_core_emails]

      if @_store_locale_active
        super
      else
        # Subclasses that call `mail` without wrapping their action in
        # `with_store_locale` (e.g. Devise mailers, extensions) still get the
        # store default locale, as `mail` applied before Spree 5.6.
        with_store_locale(current_store) { super }
      end
    end

    # @deprecated Each mailer action now wraps its body in {#with_store_locale},
    #   which also activates the store's translation fallbacks and restores the
    #   previous locale afterwards. This method mutates `I18n.locale` for the rest
    #   of the thread without restoring it. Will be removed in Spree 6.0.
    def set_email_locale
      Spree::Deprecation.warn(
        'Spree::BaseMailer#set_email_locale is deprecated and will be removed in Spree 6.0. ' \
        'Wrap the mailer action body in `with_store_locale(store, locale) { ... }` instead.'
      )
      locale = @order&.locale.presence || @order&.store&.default_locale || current_store&.default_locale
      I18n.locale = locale if locale.present?
    end

    protected

    # The "<store> <subject> #<number>" subject line shared by customer-facing
    # order emails, with the optional [RESEND] prefix.
    def order_email_subject(store, subject, number, resend: false)
      "#{resend ? "[#{Spree.t(:resend).upcase}] " : ''}#{store.name} #{subject} ##{number}"
    end

    private

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
