# What a store's back office is made of, in the order the permission pickers
# show it. Registration order IS picker order. The seller panel's own
# scopes come last, listed for the seller audience alone — staff never
# see them.
#
# Only the vocabulary lives here. How keys resolve, activate and expand is
# Spree::PermissionConfiguration; what a role actually holds is data.
module Spree
  class PermissionConfiguration
    module DefaultCatalog
      # The core vocabulary — one entry per Admin API scope scope. Resources
      # are lambdas so model classes resolve at activation, not load, time.
      # rubocop:disable Metrics/MethodLength
      def self.register(catalog)
        catalog.register_scope(:dashboard, group: :analytics, resources: -> { [:dashboard] },
                                           write: false, audiences: %i[store seller])

        # Semantic reporting (docs/plans/6.0-analytics-semantic-layer.md). Staff
        # only until seller queries get a compiler-forced seller scope.
        catalog.register_scope(:reports, group: :analytics,
                                         resources: -> { [:reports, Spree::SavedReport, Spree::Exports::Report] })

        catalog.register_scope(:orders, group: :orders, audiences: %i[store seller], resources: -> {
          [Spree::Order, Spree::OrderGroup, Spree::LineItem, Spree::TaxLine, Spree::Discount, Spree::Fee,
           Spree::Return, Spree::Exchange, Spree::Claim, Spree::TaxIdentifier,
           Spree::CustomField, Spree::DigitalLink]
        })
        catalog.register_scope(:payments, group: :orders, resources: -> { [Spree::Payment, Spree::PaymentSplit] })
        catalog.register_scope(:fulfillments, group: :orders, audiences: %i[store seller], resources: -> {
          [Spree::Fulfillment, Spree::ShippingLabel, Spree::Delivery]
        })
        catalog.register_scope(:refunds, group: :orders, resources: -> { [Spree::Refund] })

        # `Spree::Import` and its rows are resources here because a CSV import is
        # a bulk product write and nothing else — which is the same reasoning
        # that makes `write_<scope>` the key gating every import endpoint
        # (see Spree::Import.required_scope). Without them CanCanCan denies a
        # principal whose capability comes from catalog keys alone, which is
        # every seller: the key gate would pass on `write_products` and the
        # `authorize!` immediately behind it would refuse.
        #
        # An operator is unaffected either way — the `admin` role grants
        # `can :manage, :all` and never consults this list.
        catalog.register_scope(:products, group: :catalog, audiences: %i[store seller], resources: -> {
          [Spree::Product, Spree::Variant, Spree::OptionType,
           Spree::OptionValue, Spree::Price, Spree::PriceList, Spree::PriceRule,
           Spree::Catalog, Spree::CatalogProduct,
           Spree::CatalogAssignment, Spree::CustomField, Spree::DigitalAsset,
           Spree::Import, Spree::ImportRow]
        })

        # Its own scope so a seller can be granted the read without the
        # write, but the write key has to exist: the operator's endpoint serves
        # create/update/destroy, and a scope declared `write: false` has no
        # `write_product_types` for that gate to accept — every scoped key and
        # every non-admin staff role would 403
        # (docs/plans/6.0-seller-product-submission.md). Sellers hold the read
        # alone; `grantable_keys` is what bounds them, not the catalog.
        catalog.register_scope(:product_types, group: :catalog,
                                               audiences: %i[store seller], read_only_for: %i[seller],
                                               resources: -> { [Spree::ProductType] })

        # Which channels carry a product is marketplace merchandising, so this
        # is closed to the seller audience entirely — a seller lists, the
        # marketplace distributes, and the seller branch serializes no
        # publication at all.
        #
        # Publishing is written through the products endpoint rather than one of
        # its own, so `write_publishing` gates nothing today; what this
        # registration does is take `ProductPublication` out of the `products`
        # resource list, which is what a seller's role would otherwise reach. A
        # staff role that manages publications needs this key alongside
        # `write_products`.
        catalog.register_scope(:publishing, group: :catalog, resources: -> {
          [Spree::ProductPublication]
        })

        # Media is its own scope because a file is no longer a product's
        # alone: one row can be placed on a category or collection, and the
        # library lists, traces and deletes across all of them. Reaching a file
        # *through* a product still needs only `products` — the nested gallery
        # endpoints are that product's own media — but enumerating the library,
        # asking where a file is used, or deleting one everywhere is this key.
        catalog.register_scope(:media, group: :catalog, audiences: %i[store seller], resources: -> {
          [Spree::Media]
        })
        catalog.register_scope(:categories, group: :catalog, resources: -> {
          [Spree::Category, Spree::ProductCategory]
        })
        catalog.register_scope(:collections, group: :catalog, resources: -> {
          [Spree::Collection, Spree::ProductCollection, Spree::CollectionRule]
        })
        catalog.register_scope(:stock, group: :catalog, audiences: %i[store seller], resources: -> {
          [Spree::StockLevel, Spree::StockLocation, Spree::StockMovement,
           Spree::StockTransfer, Spree::StockTransferItem, Spree::StockReservation,
           Spree::StockReceipt, Spree::StockReceiptItem]
        })

        # Buying goods in, which is a different job from moving the goods you
        # already have: `write_stock` must not also mean "may place orders with
        # suppliers" (docs/plans/6.0-inventory-operations.md). Closed to the
        # seller audience — a marketplace seller does not purchase on the
        # operator's account.
        catalog.register_scope(:purchasing, group: :catalog, resources: -> {
          [Spree::Supplier, Spree::PurchaseOrder, Spree::PurchaseOrderItem,
           Spree::StockReceipt, Spree::StockReceiptItem]
        })

        catalog.register_scope(:customers, group: :customers, resources: -> {
          [Spree.customer_class, Spree::Address, Spree::CreditCard, Spree::CustomerGroup,
           Spree::Company, Spree::CompanyMembership,
           Spree::CompanyInvitation,
           Spree::TaxIdentifier, Spree::TaxExemptionCertificate,
           # GDPR records are about a customer and read alongside one, so they
           # ride the same key rather than becoming a scope of their own.
           Spree::DataRequest, Spree::ConsentRecord,
           Spree::CustomField]
        })

        # Running the marketplace: admitting sellers, approving them, suspending
        # them. Deliberately not opened to the seller audience — a seller
        # administering other sellers is the one thing this key must not allow.
        # The seller records themselves, plus what the marketplace asks of them
        # before admitting them: who decides admission is who admits, so the
        # checklist rides the same key rather than becoming a settings matter.
        catalog.register_scope(:sellers, group: :sellers, resources: -> {
          [Spree::Seller, Spree::SellerRequirement, Spree::SellerRequirementSubmission]
        })

        # What the marketplace charges its sellers. Its own scope rather than
        # part of `settings`, and closed to the seller audience for the same
        # reason `sellers` is: a seller must never be able to read, let alone
        # set, what anyone is charged.
        catalog.register_scope(:commissions, group: :sellers, resources: -> {
          [Spree::CommissionRate, Spree::CommissionRule, Spree::CommissionLine]
        })

        # What the marketplace owes its sellers, and what it has sent them.
        # Separate from `commissions` because they are opposite directions of the
        # same relationship, and a finance operator often needs one without the
        # other. Closed to the seller audience: a seller reads their own earnings
        # through their own branch, scope-fetched, never through a key that could
        # reach the whole ledger.
        catalog.register_scope(:payouts, group: :sellers, resources: -> {
          [Spree::SellerTransfer, Spree::SellerPayout]
        })

        # Stored value is not a promotion and not an order: a gift card or a
        # store credit is prepaid money the store owes. Its own group, mirroring
        # the dashboard's Loyalty nav. The KEY names are unchanged, so roles
        # created before the move keep working.
        catalog.register_scope(:gift_cards, group: :loyalty, resources: -> {
          [Spree::GiftCard, Spree::GiftCardBatch]
        })
        catalog.register_scope(:store_credits, group: :loyalty, resources: -> {
          [Spree::StoreCredit, Spree::StoreCreditEvent]
        })

        catalog.register_scope(:promotions, group: :marketing, resources: -> {
          [Spree::Promotion, Spree::PromotionRule, Spree::PromotionAction,
           Spree::PromotionCategory, Spree::CouponCode, Spree::CustomField]
        })

        catalog.register_scope(:settings, group: :settings, resources: -> {
          [Spree::Store, Spree::PaymentMethod, Spree::Gateway,
           Spree::DeliveryZone, Spree::DeliveryZoneMember,
           Spree::StockLocation, Spree::DeliveryProfile,
           Spree::Market, Spree::TaxCategory, Spree::TaxRate, Spree::AllowedOrigin,
           Spree::RefundReason, Spree::ReturnReason, Spree::ClaimReason,
           Spree::OrderCancellationReason, Spree::Channel,
           Spree::OrderRoutingRule, Spree::CustomFieldDefinition, Spree::Policy]
        })

        # How goods actually get shipped and what that costs. Its own scope
        # rather than part of `settings` because on a marketplace a seller owns
        # their own methods, and `settings` is never seller-grantable — the rest
        # of what it covers is store-wide administration
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
        #
        # The profiles and zones these methods hang off stay in `settings`: the
        # marketplace defines that vocabulary and a seller only reads it.
        catalog.register_scope(:delivery_methods, group: :settings, audiences: %i[store seller], resources: -> {
          [Spree::DeliveryMethod, Spree::DeliveryMethodRule, Spree::DeliveryMethodService]
        })

        # What goods are packed into: the marketplace's boxes and cartons, and
        # each seller's own. Its own scope rather than part of `settings` for
        # the same reason `delivery_methods` is — a seller owns their packaging
        # and `settings` is never seller-grantable
        # (docs/plans/6.0-seller-package-types.md).
        catalog.register_scope(:package_types, group: :settings, audiences: %i[store seller], resources: -> {
          [Spree::PackageType]
        })
        catalog.register_scope(:webhooks, group: :settings, resources: -> {
          [Spree::WebhookEndpoint, Spree::WebhookDelivery]
        })
        catalog.register_scope(:integrations, group: :settings, resources: -> { [Spree::Integration] })

        catalog.register_scope(:api_keys, group: :access, resources: -> { [Spree::ApiKey] })
        catalog.register_scope(:staff, group: :access, resources: -> {
          [Spree.admin_user_class, Spree::Invitation, Spree::Role, Spree::RoleUser]
        })

        # The seller panel's own scopes. Their audience is the seller alone,
        # so they grant a seller's role what it needs while staying out of the
        # staff permission picker, where a store role could never usefully
        # hold them.

        # A seller editing their own record: profile, branding, addresses,
        # onboarding.
        #
        # A symbol resource, not `Spree::Seller`: that class belongs to `sellers`
        # above — the operator's key — and claiming it twice would make
        # `scope_for_resource` answer by registration order, besides letting a
        # seller's key manage seller records generally. A symbol grants a real
        # `can` rule (so `authorize!` on the seller branch resolves) while
        # staying invisible to `scope_for_resource`, which matches Classes
        # only. Which seller they may touch is still `current_seller`
        # scope-fetching, never an ability rule.
        catalog.register_scope(:seller_profile, group: :seller, resources: -> { [:seller_profile] },
                                                audiences: %i[seller])

        # A seller reading their own books: balance, earnings, settlements.
        #
        # Its own key rather than part of `seller_profile`, so an owner can hand
        # a packing teammate the orders without the money. Read-only, and a
        # symbol for the reason `seller_profile` is one: the ledger classes
        # belong to `payouts`, the operator's key. Which rows a seller reads is
        # `current_seller` scope-fetching on their own branch.
        catalog.register_scope(:seller_earnings, group: :seller, resources: -> { [:seller_earnings] },
                                                 write: false, audiences: %i[seller])
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
