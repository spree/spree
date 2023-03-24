module Spree
  module TranslatableResourceSlug
    extend ActiveSupport::Concern

    included do
      def localized_slugs_for_store(store)
        localized_slugs = Hash[translations.pluck(:locale, :slug)]
        default_locale = store.default_locale
        supported_locales = store.supported_locales_list

        supported_locales.each_with_object({}) do |locale, hash|
          hash[locale] = localized_slugs[locale] || localized_slugs[default_locale]
        end
      end
    end
  end
end
