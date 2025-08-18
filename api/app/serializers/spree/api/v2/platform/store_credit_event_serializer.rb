module Spree
  module Api
    module V2
      module Platform
        class StoreCreditEventSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :store_credit, serializer: Spree::Api::Dependencies.platform_store_credit_serializer.constantize
          belongs_to :originator, polymorphic: true
        end
      end
    end
  end
end
