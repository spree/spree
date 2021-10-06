module Spree
  module Api
    module V2
      module Platform
        class AddressSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :country
          belongs_to :state
          belongs_to :user
        end
      end
    end
  end
end
