module Spree
  module Api
    module V3
      module Admin
        # A product as seen from one catalog: everything the admin product
        # serializer says, plus what a buyer on this agreement actually pays
        # for it and where that number comes from.
        #
        # `catalog_price` is expanded rather than always sent, because
        # resolving it costs a query per page that the picker and the plain
        # membership listing have no use for
        # (docs/plans/6.0-catalog-agreement-rework.md).
        class CatalogProductSerializer < Spree::Api::V3::Admin::ProductSerializer
          typelize catalog_price: ['CatalogPrice', nullable: true]

          # Priced off the same variant the row's own price is read from, so
          # the agreement's amount and the shop's describe the same offer.
          #
          # Null means nothing prices this variant in this currency at all —
          # distinct from a `base` source, which is a real amount the
          # agreement simply does not touch.
          attribute :catalog_price, if: proc { expand?('catalog_price') } do |product|
            resolver = params[:catalog_price_resolver]
            price = resolver&.call(featured_variant(product))

            Spree.api.admin_catalog_price_serializer.new(price, params: params).to_h if price
          end
        end
      end
    end
  end
end
