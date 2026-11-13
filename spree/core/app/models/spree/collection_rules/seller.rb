module Spree
  module CollectionRules
    # Products a marketplace seller lists.
    class Seller < Spree::CollectionRule
      include RecordValue

      self.value_association = :sellers

      def apply(scope)
        match(scope, Spree::Product.where(seller_id: value))
      end
    end
  end
end
