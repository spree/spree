module Spree
  class Classification < Spree::Base
    self.table_name = 'spree_products_taxons'
    acts_as_list scope: :taxon
    belongs_to :product, inverse_of: :classifications, touch: true
    belongs_to :taxon, inverse_of: :classifications, touch: true

    # For #3494
    validates_uniqueness_of :taxon_id, scope: :product_id, message: :already_linked
  end
end
