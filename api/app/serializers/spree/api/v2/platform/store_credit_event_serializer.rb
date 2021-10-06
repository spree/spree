module Spree
  module Api
    module V2
      module Platform
        class StoreCreditEventSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :store_credit
          belongs_to :originator, polymorphic: true
        end
      end
    end
  end
end
