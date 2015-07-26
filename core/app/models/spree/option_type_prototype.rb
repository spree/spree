module Spree
  class OptionTypePrototype < Spree::Base
    belongs_to :option_type, class_name: 'Spree::OptionType'
    belongs_to :prototype, class_name: 'Spree::Prototype'
  end
end
