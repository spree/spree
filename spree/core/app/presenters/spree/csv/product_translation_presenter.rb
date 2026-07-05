module Spree
  module CSV
    class ProductTranslationPresenter
      CSV_HEADERS = %w[
        slug
        locale
        name
        description
        meta_title
        meta_description
      ].freeze

      TRANSLATABLE_FIELDS = %i[name description meta_title meta_description].freeze

      def initialize(product, locale)
        @product = product
        @locale = locale.to_s
      end

      attr_reader :product, :locale

      def call
        [
          product.slug,
          locale,
          *TRANSLATABLE_FIELDS.map { |field| product.get_field_with_locale(locale, field) }
        ]
      end
    end
  end
end
