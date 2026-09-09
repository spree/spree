module Spree
  module Api
    module V3
      module Admin
        # A product as seen from one catalog: what the membership card renders,
        # plus what a buyer on this agreement actually pays for it and where
        # that number comes from.
        #
        # The rows are expanded rather than always sent, because resolving
        # them costs a query per page that the picker and the plain membership
        # listing have no use for (docs/plans/6.0-catalog-agreement-rework.md).
        # There is deliberately no product-level price: the card prices
        # variants, and a figure on the product row would have to pick one
        # variant to speak for the rest (docs/plans/6.0-volume-pricing.md).
        class CatalogProductSerializer < Admin::MembershipProductSerializer
          typelize quantity_rule: ['CatalogProductTerm', nullable: true]

          # Priced off the same variant the row's own price is read from, so
          # the agreement's amount and the shop's describe the same offer.
          #
          # Null means nothing prices this variant in this currency at all —
          # distinct from a `base` source, which is a real amount the
          # agreement simply does not touch.
          # This product's quantity terms under the agreement, rolled up from
          # the variant rows the page already loaded. Its own request used to
          # fetch every rule in the catalog unpaginated and group them the
          # same way, which is the same object graph this endpoint holds
          # (docs/plans/6.0-volume-pricing.md).
          attribute :quantity_rule, if: proc { expand?('quantity_rule') } do |product|
            rules = params[:catalog_quantity_rules]&.fetch(product.id, nil)

            if rules.present?
              term = Spree::Catalogs::ProductTerm.new(product: product, rules: rules)
              Spree.api.admin_catalog_product_term_serializer.new(term, params: params).to_h
            end
          end

          # Every variant with what this agreement charges for it. A product's
          # variants can be priced differently — and carry different quantity
          # ladders — so a single figure on the product row names one variant's
          # deal and hides the rest (docs/plans/6.0-volume-pricing.md).
          # `source:` rather than a plain association: the rows are resolved
          # per request against the catalog's price list, which the serializer
          # receives in params rather than the product carrying it.
          many :catalog_variants,
               resource: proc { Spree.api.admin_catalog_price_serializer },
               if: proc { expand?('catalog_price') },
               source: lambda { |params|
                 resolver = params[:catalog_price_resolver]

                 variants.filter_map { |variant| resolver&.call(variant) }
               }
        end
      end
    end
  end
end
