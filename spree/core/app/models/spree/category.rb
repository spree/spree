module Spree
  # Public API name for Taxon. Will become the base class in 6.0
  # when spree_taxons table is renamed to spree_categories.
  class Category < Taxon
  end
end
