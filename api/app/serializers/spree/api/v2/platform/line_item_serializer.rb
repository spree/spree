module Spree
  module Api
    module V2
      module Platform
        class LineItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :tax_category
          belongs_to :variant

          has_many :adjustments
          has_many :inventory_units
        end
      end
    end
  end
end
