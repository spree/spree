module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        attributes :id, :name, :presentation, :position

        many :option_values,
             resource: Spree.api.v3_storefront_option_value_serializer,
             if: proc { params[:includes]&.include?('option_values') }
      end
    end
  end
end
