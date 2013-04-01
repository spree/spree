module Spree
  class Classification < ActiveRecord::Base
    self.table_name = 'spree_products_taxons'
    belongs_to :product
    belongs_to :taxon
  end
end
