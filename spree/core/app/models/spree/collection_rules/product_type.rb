module Spree
  module CollectionRules
    class ProductType < Spree::CollectionRule
      include RecordValue

      self.value_association = :product_types

      def apply(scope)
        match(scope, Spree::Product.where(product_type_id: value))
      end
    end
  end
end
