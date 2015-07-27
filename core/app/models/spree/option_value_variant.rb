module Spree
  class OptionValueVariant < Spree::Base
    belongs_to :option_value, class_name: 'Spree::OptionValue'
    belongs_to :variant, class_name: 'Spree::Variant'
  end
end
