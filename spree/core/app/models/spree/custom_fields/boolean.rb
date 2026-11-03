module Spree
  module CustomFields
    class Boolean < Spree::CustomField
      normalizes :value, with: ->(value) { Spree::Boolean.cast(value).to_s }

      def csv_value
        Spree::Boolean.cast(value) ? I18n.t('spree.say_yes') : I18n.t('spree.say_no')
      end

      def serialize_value
        Spree::Boolean.cast(value)
      end
    end
  end
end
