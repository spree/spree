module Spree
  module Api
    module V2
      module Platform
        class AdjustmentSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :adjustable, polymorphic: true
          belongs_to :source, polymorphic: {
            Spree::Promotion::Actions::FreeShipping => :promotion_action,
            Spree::Promotion::Actions::CreateAdjustment => :promotion_action,
            Spree::Promotion::Actions::CreateItemAdjustments => :promotion_action,
            Spree::Promotion::Actions::CreateLineItems => :promotion_action
          }
        end
      end
    end
  end
end
