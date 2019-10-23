module Spree
  module V2
    module Storefront
      class StoreCreditSerializer < BaseSerializer
        set_type :store_credit

        belongs_to :category
        has_many :store_credit_events
        belongs_to :credit_type,
                   id_method_name: :type_id,
                   serializer: :store_credit_type

        attributes :amount, :amount_used, :created_at
      end
    end
  end
end
