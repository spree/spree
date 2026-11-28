module Spree
  module Api
    module V3
      module Admin
        # A product as listed in one collection: the admin product, plus how it
        # joined. Only a rule-matched product comes back after it is removed,
        # so it is the one worth excluding.
        class CollectionProductSerializer < Admin::ProductSerializer
          typelize membership_source: [:string, enum: Spree::ProductCollection::SOURCES, enum_type_name: 'CollectionMembershipSource',
                                                comment: '`rule` when the collection rules matched the product, `manual` when it was hand-picked']

          attribute :membership_source do |product|
            params[:membership_sources]&.fetch(product.id, nil)
          end
        end
      end
    end
  end
end
