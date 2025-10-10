module Spree
  module V2
    module Storefront
      class OptionTypeSerializer < BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        set_type   :option_type

        attributes :name, :presentation, :position, :public_metadata

        has_many   :option_values, serializer: Spree::Api::Dependencies.storefront_option_value_serializer.constantize
      end
    end
  end
end
