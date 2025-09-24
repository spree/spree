module Spree
  module V2
    module Storefront
      class StoreCreditSerializer < BaseSerializer
        set_type :store_credit

        belongs_to :category, serializer: Spree::Api::Dependencies.storefront_store_credit_category_serializer.constantize
        has_many :store_credit_events, serializer: Spree::Api::Dependencies.storefront_store_credit_event_serializer.constantize
        belongs_to :credit_type,
                   id_method_name: :type_id,
                   serializer: Spree::Api::Dependencies.storefront_store_credit_type_serializer.constantize

        attributes :amount, :amount_used, :created_at, :public_metadata
      end
    end
  end
end
