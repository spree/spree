module Spree
  module TranslatableResource
    extend ActiveSupport::Concern

    included do
      extend Mobility

      def translatable_fields
        self.class.const_get(:TRANSLATABLE_FIELDS)
      end

      def get_field_with_locale(locale, field_name, fallback: false)
        # method will return nil if no translation is present due to fallback: false setting
        public_send(field_name, locale: locale, fallback: fallback)
      end
    end
  end
end
