module Spree
  module Api
    module V2
      module Platform
        class AdjustmentSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :adjustable, polymorphic: true
          belongs_to :source, polymorphic: true
        end
      end
    end
  end
end
