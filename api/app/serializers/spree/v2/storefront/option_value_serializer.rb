module Spree
  module V2
    module Storefront
      class OptionValueSerializer < BaseSerializer
        set_type   :option_value

        attributes :name, :presentation, :position, :public_metadata

        belongs_to :option_type, serializer: Spree::Api::Dependencies.storefront_option_type_serializer.constantize
      end
    end
  end
end
