module Spree
  module CollectionRules
    # Products in a category, optionally with its subcategories.
    class Category < Spree::CollectionRule
      include RecordValue

      self.value_association = :categories

      preference :include_descendants, :boolean, default: false

      def apply(scope)
        category = value_record
        return negated? ? scope : scope.none if category.nil?

        category_ids = preferred_include_descendants ? category.cached_self_and_descendants_ids : [category.id]
        match(scope, Spree::Product.where(id: Spree::ProductCategory.where(category_id: category_ids).select(:product_id)))
      end
    end
  end
end
