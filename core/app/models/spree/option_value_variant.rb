module Spree
  class OptionValueVariant < Spree::Base
    belongs_to :option_value, class_name: 'Spree::OptionValue'
    belongs_to :variant, class_name: 'Spree::Variant'

    validates :option_value, :variant, presence: true
    validates :option_value_id, uniqueness: { scope: :variant_id }
  end
end
