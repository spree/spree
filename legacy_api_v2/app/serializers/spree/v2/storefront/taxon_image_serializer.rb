module Spree
  module V2
    module Storefront
      class TaxonImageSerializer < BaseSerializer
        include ::Spree::Api::V2::TaxonImageTransformationConcern

        set_type   :taxon_image

        attributes :styles, :alt, :original_url
      end
    end
  end
end
