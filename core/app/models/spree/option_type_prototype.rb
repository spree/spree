module Spree
  class OptionTypePrototype < Spree::Base
    belongs_to :option_type, class_name: 'Spree::OptionType'
    belongs_to :prototype, class_name: 'Spree::Prototype'

    validates :prototype, :option_type, presence: true
    validates :prototype_id, uniqueness: { scope: :option_type_id }
  end
end
