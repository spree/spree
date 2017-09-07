module Spree
  class Classification < Spree::Base
    self.table_name = 'spree_products_taxons'
    acts_as_list scope: :taxon

    with_options inverse_of: :classifications, touch: true do
      belongs_to :product, class_name: 'Spree::Product'
      belongs_to :taxon, class_name: 'Spree::Taxon'
    end

    validates :taxon, :product, presence: true
    # For #3494
    validates :taxon_id, uniqueness: { scope: :product_id, message: :already_linked, allow_blank: true }
  end
end
