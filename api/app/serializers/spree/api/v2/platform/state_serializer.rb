module Spree
  module Api
    module V2
      module Platform
        class StateSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          belongs_to :country
        end
      end
    end
  end
end
