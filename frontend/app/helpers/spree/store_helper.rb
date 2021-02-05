module Spree
  module StoreHelper
    def store_country_iso(store)
      store ||= current_store
      return unless store
      return unless store.default_country

      store.default_country.iso.downcase
    end

    def stores
      @stores ||= Spree::Store.includes(:default_country).order(:id)
    end

    def store_currency_symbol(store)
      store ||= current_store
      return unless store
      return unless store.default_currency

      ::Money::Currency.find(store.default_currency).symbol
    end

    def store_locale_name(store)
      store ||= current_store
      return unless store
      return store.name if store.default_locale.blank?

      Spree.t('i18n.this_file_language', locale: store.default_locale)
    end
  end
end
