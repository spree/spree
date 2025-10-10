module Spree
  module Api
    module V2
      module Platform
        class StoreCreditSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user, serializer: Spree::Api::Dependencies.platform_user_serializer.constantize
          belongs_to :created_by, serializer: Spree::Api::Dependencies.platform_admin_user_serializer.constantize
          belongs_to :store_credit_category, object_method_name: :category, id_method_name: :category_id, serializer: Spree::Api::Dependencies.platform_store_credit_category_serializer.constantize
          belongs_to :store_credit_type, object_method_name: :credit_type, id_method_name: :type_id, serializer: Spree::Api::Dependencies.platform_store_credit_type_serializer.constantize

          has_many :store_credit_events, serializer: Spree::Api::Dependencies.platform_store_credit_event_serializer.constantize
        end
      end
    end
  end
end
