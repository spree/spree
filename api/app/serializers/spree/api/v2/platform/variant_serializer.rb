module Spree
  module Api
    module V2
      module Platform
        class VariantSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          attributes :name, :width, :options_text, :option_values

          belongs_to :product
          has_many :images
          has_many :option_values
        end
      end
    end
  end
end
