module Spree
  module Locales
    class SetFallbackLocaleForStore
      def call(store:)
        store_default_locale = store.default_locale
        return unless store_default_locale.present?

        fallbacks = store.supported_locales_list.each_with_object({}) do |locale, object|
          object[locale] = [store_default_locale]
        end

        fallbacks_instance = I18n::Locale::Fallbacks.new(fallbacks)

        Mobility.store_based_fallbacks = fallbacks_instance
      end
    end
  end
end
