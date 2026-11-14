module Spree
  module Imports
    class AssignTagsJob < Spree::Imports::BaseJob
      def perform(product_id, tags)
        product = Spree::Product.find(product_id)
        product.tag_list = tags.to_s.split(',').map(&:strip).compact_blank
        product.save!
      end
    end
  end
end
