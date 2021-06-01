module Spree
  module Api
    module V2
      module Platform
        class ClassificationSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          belongs_to :product
          belongs_to :taxon
        end
      end
    end
  end
end
