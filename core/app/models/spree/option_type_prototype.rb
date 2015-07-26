module Spree
  class OptionTypeProtoype < Spree::Base
    self.table_name = 'spree_option_types_prototypes'

    belongs_to :option_type, class_name: 'Spree::OptionType'
    belongs_to :prototype, class_name: 'Spree::Prototype'
  end
end
