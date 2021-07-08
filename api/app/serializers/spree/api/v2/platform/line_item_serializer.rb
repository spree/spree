module Spree
  module Api
    module V2
      module Platform
        class LineItemSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          belongs_to :variant
        end
      end
    end
  end
end
