module Spree
  module TranslatableResourceSlug
    extend ActiveSupport::Concern

    included do
      def localized_slugs_for_store(store)
        supported_locales = store.supported_locales_list

        supported_locales.each_with_object({}) do |locale, hash|
          hash[locale] = I18n.with_locale(locale) { slug }
        end
      end
    end
  end
end
