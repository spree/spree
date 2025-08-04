module Spree
  module Api
    module V2
      module Platform
        class ReturnItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :exchange_inventory_units, serializer: Spree::Api::Dependencies.platform_inventory_unit_serializer.constantize, type: :inventory_unit
          belongs_to :exchange_variant, serializer: Spree::Api::Dependencies.platform_variant_serializer.constantize, type: :variant
          belongs_to :preferred_reimbursement_type, serializer: Spree::Api::Dependencies.platform_reimbursement_type_serializer.constantize, type: :reimbursement_type
          belongs_to :override_reimbursement_type, serializer: Spree::Api::Dependencies.platform_reimbursement_type_serializer.constantize, type: :reimbursement_type
        end
      end
    end
  end
end
