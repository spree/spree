module Spree
  module TranslatableResource
    extend ActiveSupport::Concern

    included do
      extend Mobility
      default_scope { i18n }

      def get_field_with_locale(locale, field_name, fallback: false)
        # method will return nil if no translation is present due to fallback: false setting
        public_send(field_name, locale: locale, fallback: fallback)
      end
    end

    class_methods do
      def translatable_fields
        const_get(:TRANSLATABLE_FIELDS)
      end

      def translation_table_alias
        "#{self::Translation.table_name}_#{Mobility.normalize_locale(Mobility.locale)}"
      end

      def arel_table_alias
        Arel::Table.new(translation_table_alias)
      end
    end
  end
end
