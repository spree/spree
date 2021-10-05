module Spree
  module Api
    module V2
      module Platform
        class StoreCreditSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user
          belongs_to :created_by, serializer: :user, type: :user
          belongs_to :store_credit_category, object_method_name: :category, id_method_name: :category_id
          belongs_to :store_credit_type, object_method_name: :credit_type, id_method_name: :type_id

          has_many :store_credit_events
        end
      end
    end
  end
end
