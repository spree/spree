module Spree
  class PrototypeTaxon < Spree::Base
    belongs_to :taxon
    belongs_to :prototype
  end
end
