module Spree
  module V2
    module Storefront
      class OptionTypeSerializer < BaseSerializer
        set_type   :option_type

        attributes :name, :presentation, :position

        has_many   :option_values
      end
    end
  end
end
