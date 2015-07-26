module Spree
  class OptionValueVariant < Spree::Base
    self.table_name = 'spree_option_values_variants'

    belongs_to :option_value, class_name: 'Spree::OptionValue'
    belongs_to :variant, class_name: 'Spree::Variant'
  end
end
