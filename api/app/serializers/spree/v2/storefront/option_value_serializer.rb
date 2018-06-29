module Spree
  module V2
    module Storefront
      class OptionValueSerializer < BaseSerializer
        set_type   :option_value

        attributes :id, :name, :presentation, :position
      end
    end
  end
end
