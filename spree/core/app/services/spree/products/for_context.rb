module Spree
  module Products
    # Resolves which products a buyer may see: the channel's publications,
    # narrowed by the catalogs that apply to them.
    #
    # Precedence, per docs/plans/6.0-b2b-companies-and-catalogs.md:
    # 1. A buyer resolving to a company node with effective catalogs sees the
    #    union of those catalogs' assortments.
    # 2. Otherwise, a customer whose groups carry catalogs sees their union.
    # 3. Otherwise, every channel listing — narrowed to the channel's default
    #    catalog when one is set.
    #
    # Gated storefront access (login_required) runs before this resolver — a
    # gated guest never reaches it.
    class ForContext
      prepend Spree::ServiceModule::Base

      # @param store [Spree::Store]
      # @param channel [Spree::Channel]
      # @param customer [Object, nil]
      # @param company [Spree::Company, nil] the purchase node; defaults to
      #   the customer's sole standing within the store
      # @param base [ActiveRecord::Relation, nil] the already-scoped listing
      #   to narrow; defaults to the channel's publications
      # @return [Spree::ServiceModule::Result] value is a Product relation
      def call(store:, channel:, customer: nil, company: nil, base: nil)
        base ||= store.products.for_channel(channel)
        company ||= sole_standing_company(store, customer)

        catalogs = Spree::Catalog.effective_for_company(company)
        catalogs = customer_group_catalogs(store, customer) if catalogs.empty?
        catalogs = [channel&.default_catalog].compact.select(&:active?) if catalogs.empty?

        return success(base) if catalogs.empty?

        # An empty assortment means the whole channel range: such a catalog is
        # a pricing-only overlay (its price list applies, nothing is hidden),
        # so one in the effective set lifts the restriction entirely — the
        # union includes "all". Only a set of curated catalogs narrows.
        catalog_ids = catalogs.map(&:id)
        curated_ids = Spree::CatalogProduct.where(catalog_id: catalog_ids).distinct.pluck(:catalog_id)
        return success(base) if (catalog_ids - curated_ids).any?

        success(base.where(
          id: Spree::CatalogProduct.where(catalog_id: catalog_ids).select(:product_id)
        ))
      end

      private

      def sole_standing_company(store, customer)
        return nil if customer.nil?

        memberships = customer.company_memberships.
                      joins(:company).
                      merge(Spree::Company.where(store_id: store.id)).
                      to_a.uniq

        memberships.one? ? memberships.first.company : nil
      end

      def customer_group_catalogs(store, customer)
        return [] if customer.nil?

        groups = customer.customer_groups.where(store_id: store.id)
        Spree::Catalog.effective_for_customer_groups(groups)
      end
    end
  end
end
