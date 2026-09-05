module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        typelize name: :string, label: :string, position: :number, kind: :string

        attributes :name, :label, :position, :kind

        # The values this axis is sold in. Expanded rather than always sent,
        # since a product listing has no use for them — but a picker does,
        # whether it is a storefront's size selector or a seller choosing the
        # condition their offer is in
        # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 7).
        many :option_values,
             resource: proc { Spree.api.option_value_serializer },
             if: proc { expand?('option_values') }
      end
    end
  end
end
