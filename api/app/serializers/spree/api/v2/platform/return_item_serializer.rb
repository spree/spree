module Spree
  module Api
    module V2
      module Platform
        class ReturnItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :exchange_inventory_units, serializer: :inventory_unit, type: :inventory_unit
          belongs_to :exchange_variant, serializer: :variant, type: :variant
          belongs_to :preferred_reimbursement_type, serializer: :reimbursement_type, type: :reimbursement_type
          belongs_to :override_reimbursement_type, serializer: :reimbursement_type, type: :reimbursement_type
        end
      end
    end
  end
end
