module Spree
  module Api
    module V3
      # One option pair of a variant, such as size Small. Option types and values are created when missing.
      class VariantOptionRequestSchema < Spree::Api::V3::RequestSchema
        publishes 'VariantOptionParams'

        string :name, required: true, example: 'size'
        string :value, required: true, example: 'Small'
      end
    end
  end
end
