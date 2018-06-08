module Spree
  module V2
    module Storefront
      class TaxonImageSerializer < BaseSerializer
        set_type   :taxon_image

        attributes :viewable_type, :viewable_id, :styles
      end
    end
  end
end
