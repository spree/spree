module Spree
  class TranslatableResource < Spree::Base
    self.abstract_class = true
    extend Mobility

    def translatable_fields
      # I think better solution is to implement get_translatable_fields in mobility gem(?)
      self.class.const_get(:TRANSLATABLE_FIELDS)
    end

    # do we want to add fallback parameter?
    def get_field_with_locale(locale, field_name)
      # method will return nil if no translation is present due to fallback: false setting
      public_send(field_name, locale: locale, fallback: false)
    end
  end
end
