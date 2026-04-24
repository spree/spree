module Spree
  module Imports
    module RowProcessors
      class ProductTranslation < Base
        TRANSLATABLE_FIELDS = %w[name description meta_title meta_description].freeze

        def initialize(row, **)
          super
          @store = row.store
        end

        attr_reader :store

        def process!
          locale = attributes['locale'].to_s.strip
          raise ArgumentError, 'Locale is required' if locale.blank?

          slug = attributes['slug'].to_s.strip
          raise ArgumentError, 'Slug is required' if slug.blank?

          product = product_scope.find_by!(slug: slug)

          translation_attrs = TRANSLATABLE_FIELDS.each_with_object({}) do |field, hash|
            value = attributes[field]
            hash[field.to_sym] = value.to_s.strip if value.present?
          end

          return product if translation_attrs.empty?

          Mobility.with_locale(locale) do
            product.update!(translation_attrs)
          end

          product
        end

        private

        def product_scope
          Spree::Product.accessible_by(import.current_ability, :manage)
        end
      end
    end
  end
end
