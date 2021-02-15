module Spree
  module StoreHelper
    def store_country_iso(store = nil)
      store ||= current_store if defined?(current_store)

      store&.default_country&.iso&.downcase
    end

    def stores
      @stores ||= Spree::Store.includes(:default_country).order(:id)
    end

    def store_currency_symbol(store = nil)
      store ||= current_store  if defined?(current_store)
      return unless store&.default_currency

      ::Money::Currency.find(store.default_currency).symbol
    end

    def store_locale_name(store = nil)
      store ||= current_store if defined?(current_store)
      return unless store
      return store.name if store.default_locale.blank?

      Spree.t('i18n.this_file_language', locale: store.default_locale)
    end

    def should_render_store_chooser?
      Spree::Config.show_store_selector && stores.size > 1
    end

    def store_link(store = nil, html_opts = {})
      store ||= current_store if defined?(current_store)
      return unless store

      link_to "#{store_locale_name(store)} (#{store_currency_symbol(store)})", store.formatted_url, **html_opts
    end
  end
end
