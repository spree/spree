module Spree
  module V2
    module Storefront
      class TaxonomySerializer < BaseSerializer
        set_type   :taxonomy

        attributes :name, :position, :public_metadata
      end
    end
  end
end
