module Spree
  module CustomFields
    class Boolean < Spree::CustomField
      normalizes :value, with: ->(value) { value.to_b.to_s }

      def csv_value
        value.to_b ? I18n.t('spree.say_yes') : I18n.t('spree.say_no')
      end

      def serialize_value
        value.to_b
      end
    end
  end
end
