module Spree
  module Locales
    class SetFallbackLocaleForStore
      def call(store:)
        store_default_locale = store.default_locale
        return unless store_default_locale.present?

        fallbacks = store.supported_locales_list.each_with_object({}) do |locale, object|
          object[locale] = [store_default_locale]
        end

        # Pass the store default as the terminal default so EVERY locale —
        # including regional variants not in `supported_locales_list` (e.g.
        # `pt-BR` when only `pt` is configured) — ultimately falls back to it.
        # The store default resolves to the populated DB column via Mobility's
        # `column_fallback`, so translated reads never return nil for a locale
        # that lacks a translation row.
        fallbacks_instance = I18n::Locale::Fallbacks.new(store_default_locale, fallbacks)

        Mobility.store_based_fallbacks = fallbacks_instance
      end
    end
  end
end
