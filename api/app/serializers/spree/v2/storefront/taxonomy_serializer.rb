module Spree
  module V2
    module Storefront
      class TaxonomySerializer < BaseSerializer
        set_type   :taxonomy

        attributes :id, :name

        has_one    :root, record_type: :taxon, serializer: :taxon
      end
    end
  end
end
