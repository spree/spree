module Spree
  module V2
    module Storefront
      class OptionValueSerializer < BaseSerializer
        set_type   :option_value

        attributes :name, :presentation, :position

        belongs_to :option_type
      end
    end
  end
end
