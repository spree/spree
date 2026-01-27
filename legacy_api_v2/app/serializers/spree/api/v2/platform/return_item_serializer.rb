module Spree
  module Api
    module V2
      module Platform
        class ReturnItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :exchange_inventory_units, serializer: Spree.api.platform_inventory_unit_serializer, type: :inventory_unit
          belongs_to :exchange_variant, serializer: Spree.api.platform_variant_serializer, type: :variant
          belongs_to :preferred_reimbursement_type, serializer: Spree.api.platform_reimbursement_type_serializer, type: :reimbursement_type
          belongs_to :override_reimbursement_type, serializer: Spree.api.platform_reimbursement_type_serializer, type: :reimbursement_type
        end
      end
    end
  end
end
