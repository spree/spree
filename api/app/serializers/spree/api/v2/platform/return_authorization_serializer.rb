module Spree
  module Api
    module V2
      module Platform
        class ReturnAuthorizationSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :stock_location
          belongs_to :return_authorization_reason, object_method_name: :reason

          has_many :return_items
        end
      end
    end
  end
end
