module Spree
  module Variants
    class TouchJob < Spree::BaseJob
      def perform(variant_ids)
        Spree::Variant.where(id: variant_ids).find_each(&:touch)
      end
    end
  end
end
