module Spree
  module Api
    module V3
      module Admin
        # A product as the price list's own page reads it: what the membership
        # card renders, plus what the list charges for it per variant — a
        # ladder shown where it is edited and not only where it is sold
        # (docs/plans/6.0-volume-pricing.md).
        #
        # The rows are expanded rather than always sent, because resolving
        # them costs a query per page that the picker has no use for. There is
        # deliberately no product-level price: the card prices variants, and a
        # figure on the product row would have to pick one variant to speak
        # for the rest (docs/plans/6.0-volume-pricing.md).
        class PriceListProductSerializer < Admin::MembershipProductSerializer
          # Every variant with what this list charges for it, each with its
          # own ladder. `source:` rather than an association: the rows are
          # resolved per request against the list, which the serializer
          # receives in params.
          many :price_list_variants,
               resource: proc { Spree.api.admin_catalog_price_serializer },
               if: proc { expand?('price_list_price') },
               source: lambda { |params|
                 resolver = params[:price_list_price_resolver]

                 variants.filter_map { |variant| resolver&.call(variant) }
               }
        end
      end
    end
  end
end
