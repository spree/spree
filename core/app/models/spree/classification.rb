module Spree
  class Classification < ActiveRecord::Base
    self.table_name = 'spree_products_taxons'
    belongs_to :product, class_name: "Spree::Product"
    belongs_to :taxon, class_name: "Spree::Taxon"
  end
end
