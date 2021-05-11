module Spree
  module Api
    module V2
      module Platform
        class VariantSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          belongs_to :product
          has_many :images
          has_many :option_values
        end
      end
    end
  end
end
