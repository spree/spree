# The permission catalog — the single grant vocabulary shared by staff roles
# and secret API keys (see docs/plans/6.0-admin-rbac.md).
#
# Code defines the vocabulary, data defines the roles: core and extensions
# register *resources* here, and each registration yields the grantable
# `read_<resource>` / `write_<resource>` keys. Roles store keys on their row
# (`Spree::Role#permissions`); API keys store them as scopes
# (`Spree::ApiKey#scopes`). There is no code-managed role concept.
#
# @example Registering a resource from an extension
#   Spree.permissions.register_resource(:reviews, group: :catalog, subjects: -> {
#     [SpreeReviews::Review]
#   })
#
module Spree
  class PermissionConfiguration
    # Raised when a 5.x initializer still calls the removed permission-set API.
    class PermissionSetsRemovedError < StandardError; end

    READ_PREFIX = 'read_'.freeze
    WRITE_PREFIX = 'write_'.freeze

    # A role's audience is its owning resource, lowercased — a role on a
    # `Spree::Store` is `:store`, one on a `Spree::Seller` is `:seller` (see
    # `Spree::Role#audience`).
    #
    # The store's own back office is the baseline: every resource is grantable
    # there, so registrations name only the *additional* audiences they open up.
    STAFF_AUDIENCE = :store

    # A registered catalog resource. Yields one or two grantable keys and maps
    # them to the CanCanCan subjects they cover.
    class Resource
      attr_reader :name, :group

      # @param name [Symbol] resource identifier (`:orders`)
      # @param group [Symbol] UI grouping for the permission pickers
      # @param subjects [Proc, Array] CanCanCan subjects covered by this
      #   resource; pass a lambda so model classes resolve lazily
      # @param write [Boolean] whether a `write_<name>` key exists
      # @param audiences [Array<Symbol>] the non-staff audiences whose roles may
      #   hold this resource's keys
      def initialize(name:, group:, subjects:, write: true, audiences: [], read_only_for: [])
        @name = name.to_sym
        @group = group.to_sym
        @subjects = subjects
        @write = write
        @audiences = (Array(audiences).map(&:to_sym) | [STAFF_AUDIENCE]).freeze
        @read_only_for = Array(read_only_for).map(&:to_sym).freeze
      end

      # @return [Boolean]
      def write?
        @write
      end

      # @return [Array<Symbol>] every audience this resource is grantable to,
      #   staff included
      def audiences
        @audiences
      end

      # @param audience [Symbol, String, nil]
      # @return [Boolean]
      def grantable_to?(audience)
        return false if audience.blank?

        @audiences.include?(audience.to_s.to_sym)
      end

      # @return [Array<Class, Symbol>]
      def subjects
        Array(@subjects.respond_to?(:call) ? @subjects.call : @subjects)
      end

      # @return [String]
      def read_key
        "#{READ_PREFIX}#{name}"
      end

      # @return [String, nil]
      def write_key
        "#{WRITE_PREFIX}#{name}" if write?
      end

      # @return [Array<String>] the grantable keys, read first
      def keys
        [read_key, write_key].compact
      end

      # The keys one audience may hold. A resource the operator writes can
      # still be read-only for somebody else — product types are the case:
      # staff define them, a seller only picks from them.
      #
      # @param audience [Symbol, String, nil]
      # @return [Array<String>]
      def keys_for(audience)
        return [read_key] if @read_only_for.include?(audience.to_s.to_sym)

        keys
      end
    end

    def initialize
      @resources = {}
      register_default_resources
    end

    # Registers a catalog resource, yielding its `read_<name>` (and, unless
    # `write: false`, `write_<name>`) keys. Re-registering a name replaces it.
    #
    # @param name [Symbol, String]
    # @param group [Symbol] UI group (`:orders`, `:catalog`, `:marketing`,
    #   `:customers`, `:settings`, `:access`, `:analytics` — or your own)
    # @param subjects [Proc, Array] CanCanCan subjects the keys grant
    # @param write [Boolean]
    # @param audiences [Array<Symbol>] the audiences beyond staff whose roles
    #   may hold these keys (`%i[seller]`). Empty by default — opening a
    #   resource to another audience exposes it to a principal outside the
    #   store's own staff, so it is a deliberate act. Never open `settings`,
    #   `staff` or `api_keys`.
    # @return [Resource]
    def register_resource(name, group:, subjects:, write: true, audiences: [], read_only_for: [])
      # `read_all` / `write_all` are the API-key wildcard aliases — a resource
      # named `all` would silently mint keys that grant the whole catalog.
      raise ArgumentError, "the permission resource name 'all' is reserved" if name.to_s == 'all'

      resource = Resource.new(
        name: name, group: group, subjects: subjects, write: write,
        audiences: audiences, read_only_for: read_only_for
      )
      @resources[resource.name] = resource
    end

    # @param name [Symbol, String]
    # @return [Resource, nil]
    def unregister_resource(name)
      @resources.delete(name.to_sym)
    end

    # @return [Array<Resource>] in registration order (drives UI ordering)
    def resources
      @resources.values
    end

    # @param name [Symbol, String]
    # @return [Resource, nil]
    def resource(name)
      @resources[name.to_s.to_sym]
    end

    # The catalog resource whose subjects cover the given model class —
    # matching by ancestry so subclasses (e.g. a Gateway under PaymentMethod)
    # resolve to their base subject's resource. Used to derive the required
    # permission for polymorphic endpoints (translations, custom fields).
    #
    # @param klass [Class]
    # @return [Resource, nil]
    def resource_for_subject(klass)
      return nil unless klass.is_a?(Class)

      resources.find do |candidate|
        candidate.subjects.any? { |subject| subject.is_a?(Class) && klass <= subject }
      end
    end

    # One grantable key with its kind and owning resource — the unit the
    # `/admin/permissions` discovery endpoint serializes.
    class Entry
      attr_reader :key, :kind, :resource

      def initialize(key:, kind:, resource:)
        @key = key
        @kind = kind
        @resource = resource
      end
    end

    # @return [Array<String>] every grantable key, in registration order
    def catalog_keys
      resources.flat_map(&:keys)
    end

    # Resources grantable to one audience. An unknown audience simply matches
    # nothing, so a panel that does not exist yet reads as granting nothing
    # rather than raising.
    #
    # @param audience [Symbol, String] `:store`, `:seller`, …
    # @return [Array<Resource>] in registration order
    def grantable_resources(audience)
      resources.select { |resource| resource.grantable_to?(audience) }
    end

    # @param audience [Symbol, String]
    # @return [Array<String>] every key that audience may hold, in catalog order
    def grantable_keys(audience)
      grantable_resources(audience).flat_map { |resource| resource.keys_for(audience) }
    end

    # @return [Array<Entry>] every grantable key with metadata, in catalog order
    def entries
      resources.flat_map do |resource|
        resource.keys.map do |key|
          Entry.new(key: key, kind: key.start_with?(WRITE_PREFIX) ? :write : :read, resource: resource)
        end
      end
    end

    # @param key [String, Symbol]
    # @return [Boolean]
    def key?(key)
      !resolve_key(key).nil?
    end

    # Resolves a key into its kind and resource.
    #
    # @param key [String, Symbol]
    # @return [Array(Symbol, Resource), nil] `[:read | :write, resource]`
    def resolve_key(key)
      key = key.to_s
      if key.start_with?(WRITE_PREFIX)
        found = resource(key.delete_prefix(WRITE_PREFIX))
        [:write, found] if found&.write?
      elsif key.start_with?(READ_PREFIX)
        found = resource(key.delete_prefix(READ_PREFIX))
        [:read, found] if found
      end
    end

    # Applies one key's grants to a CanCanCan ability. Read keys grant
    # `[:read, :admin]`; write keys grant `:manage` (which covers read).
    #
    # @param ability [CanCan::Ability]
    # @param key [String, Symbol]
    # @return [Boolean] whether the key resolved and was applied
    def activate_key(ability, key)
      kind, found = resolve_key(key)
      return false unless found

      found.subjects.each do |subject|
        if kind == :write
          ability.can(:manage, subject)
        else
          ability.can(%i[read admin], subject)
        end
      end
      true
    end

    # Expands a key list into the full set of keys it effectively grants:
    # `write_x` implies `read_x`, and the `read_all` / `write_all` API-key
    # aliases expand against the whole catalog. Unknown keys are dropped.
    # Result preserves catalog order.
    #
    # @param keys [Array<String, Symbol>]
    # @return [Array<String>]
    def expand_keys(keys)
      keys = Array(keys).map(&:to_s)
      return catalog_keys if keys.include?('write_all')

      effective = keys.include?('read_all') ? resources.map(&:read_key) : []
      effective |= keys.flat_map do |key|
        kind, found = resolve_key(key)
        next [] unless found

        kind == :write ? [found.write_key, found.read_key] : [found.read_key]
      end
      catalog_keys & effective
    end

    # Restores the catalog to core defaults. Useful for tests that register
    # extra resources.
    def reset!
      @resources = {}
      register_default_resources
    end

    # Removed in 6.0 — roles are data now (see docs/plans/6.0-admin-rbac.md).
    # Kept only to fail loudly with directions instead of a bare NoMethodError.
    def assign(*)
      raise PermissionSetsRemovedError,
            'Permission sets were removed in Spree 6.0. Remove the permission lines from ' \
            'config/initializers/spree.rb — roles and their permissions are data now, ' \
            'managed in the dashboard (Settings → Roles), via the Admin API, or in seeds. ' \
            "Upgrade guide: https://spreecommerce.org/docs/developer/upgrades/5.6-to-6.0"
    end

    private

    # The core vocabulary — one entry per Admin API scope resource. Subjects
    # are lambdas so model classes resolve at activation, not load, time.
    # rubocop:disable Metrics/MethodLength
    def register_default_resources
      register_resource(:orders, group: :orders, audiences: %i[seller], subjects: -> {
        [Spree::Order, Spree::OrderGroup, Spree::LineItem, Spree::TaxLine, Spree::Discount, Spree::Fee,
         Spree::Return, Spree::Exchange, Spree::Claim, Spree::TaxIdentifier,
         Spree::CustomField]
      })
      register_resource(:payments, group: :orders, subjects: -> { [Spree::Payment, Spree::PaymentSplit] })
      register_resource(:fulfillments, group: :orders, audiences: %i[seller], subjects: -> { [Spree::Fulfillment] })
      register_resource(:refunds, group: :orders, subjects: -> { [Spree::Refund] })
      register_resource(:gift_cards, group: :orders, subjects: -> {
        [Spree::GiftCard, Spree::GiftCardBatch]
      })
      register_resource(:store_credits, group: :orders, subjects: -> { [Spree::StoreCredit] })

      register_resource(:products, group: :catalog, audiences: %i[seller], subjects: -> {
        [Spree::Product, Spree::Variant, Spree::OptionType,
         Spree::OptionValue, Spree::Price, Spree::PriceList, Spree::PriceRule,
         Spree::Catalog, Spree::CatalogProduct,
         Spree::CatalogAssignment, Spree::CustomField]
      })
      # Its own resource so a seller can be granted the read without the
      # write, but the write key has to exist: the operator's endpoint serves
      # create/update/destroy, and a resource declared `write: false` has no
      # `write_product_types` for that gate to accept — every scoped key and
      # every non-admin staff role would 403
      # (docs/plans/6.0-seller-product-submission.md). Sellers hold the read
      # alone; `grantable_keys` is what bounds them, not the catalog.
      register_resource(:product_types, group: :catalog,
                                        audiences: %i[seller], read_only_for: %i[seller],
                                        subjects: -> { [Spree::ProductType] })
      # Which channels carry a product is marketplace merchandising, so this
      # is closed to the seller audience entirely — a seller lists, the
      # marketplace distributes, and the seller branch serializes no
      # publication at all.
      #
      # Publishing is written through the products endpoint rather than one of
      # its own, so `write_publishing` gates nothing today; what this
      # registration does is take `ProductPublication` out of the `products`
      # subject list, which is what a seller's role would otherwise reach. A
      # staff role that manages publications needs this key alongside
      # `write_products`.
      register_resource(:publishing, group: :catalog, subjects: -> {
        [Spree::ProductPublication]
      })
      # Media is its own resource because a file is no longer a product's
      # alone: one row can be placed on a category or collection, and the
      # library lists, traces and deletes across all of them. Reaching a file
      # *through* a product still needs only `products` — the nested gallery
      # endpoints are that product's own media — but enumerating the library,
      # asking where a file is used, or deleting one everywhere is this key.
      register_resource(:media, group: :catalog, audiences: %i[seller], subjects: -> {
        [Spree::Media]
      })
      register_resource(:categories, group: :catalog, subjects: -> {
        [Spree::Category, Spree::ProductCategory]
      })
      register_resource(:collections, group: :catalog, subjects: -> {
        [Spree::Collection, Spree::ProductCollection, Spree::CollectionRule]
      })
      register_resource(:stock, group: :catalog, audiences: %i[seller], subjects: -> {
        [Spree::StockLevel, Spree::StockLocation, Spree::StockMovement,
         Spree::StockTransfer, Spree::StockReservation]
      })

      register_resource(:promotions, group: :marketing, subjects: -> {
        [Spree::Promotion, Spree::PromotionRule, Spree::PromotionAction,
         Spree::PromotionCategory, Spree::CouponCode, Spree::CustomField]
      })

      register_resource(:customers, group: :customers, subjects: -> {
        [Spree.customer_class, Spree::Address, Spree::CreditCard, Spree::CustomerGroup,
         Spree::Company, Spree::CompanyMembership,
         Spree::CompanyInvitation,
         Spree::TaxIdentifier, Spree::TaxExemptionCertificate,
         Spree::CustomField]
      })

      register_resource(:settings, group: :settings, subjects: -> {
        [Spree::Store, Spree::PaymentMethod, Spree::Gateway, Spree::DeliveryMethod,
         Spree::DeliveryMethodRule, Spree::DeliveryZone, Spree::DeliveryZoneMember,
         Spree::StockLocation, Spree::DeliveryProfile,
         Spree::Market, Spree::TaxCategory, Spree::TaxRate, Spree::AllowedOrigin,
         Spree::RefundReason, Spree::ReturnReason, Spree::ClaimReason, Spree::Channel,
         Spree::OrderRoutingRule, Spree::CustomFieldDefinition, Spree::Policy]
      })
      register_resource(:webhooks, group: :settings, subjects: -> {
        [Spree::WebhookEndpoint, Spree::WebhookDelivery]
      })
      register_resource(:integrations, group: :settings, subjects: -> { [Spree::Integration] })

      register_resource(:api_keys, group: :access, subjects: -> { [Spree::ApiKey] })
      register_resource(:staff, group: :access, subjects: -> {
        [Spree.admin_user_class, Spree::Invitation, Spree::Role, Spree::RoleUser]
      })

      # Running the marketplace: admitting sellers, approving them, suspending
      # them. Deliberately not opened to the seller audience — a seller
      # administering other sellers is the one thing this key must not allow.
      # The seller records themselves, plus what the marketplace asks of them
      # before admitting them: who decides admission is who admits, so the
      # checklist rides the same key rather than becoming a settings matter.
      register_resource(:sellers, group: :access, subjects: -> {
        [Spree::Seller, Spree::SellerRequirement, Spree::SellerRequirementSubmission]
      })

      # What the marketplace charges its sellers. Its own resource rather than
      # part of `settings`, and closed to the seller audience for the same
      # reason `sellers` is: a seller must never be able to read, let alone
      # set, what anyone is charged.
      register_resource(:commissions, group: :access, subjects: -> {
        [Spree::CommissionRate, Spree::CommissionRule, Spree::CommissionLine]
      })

      # A seller editing their own record: profile, branding, addresses,
      # onboarding.
      #
      # A symbol subject, not `Spree::Seller`: that class belongs to `sellers`
      # above — the operator's key — and claiming it twice would make
      # `resource_for_subject` answer by registration order, besides letting a
      # seller's key manage seller records generally. A symbol grants a real
      # `can` rule (so `authorize!` on the seller branch resolves) while
      # staying invisible to `resource_for_subject`, which matches Classes
      # only. Which seller they may touch is still `current_seller`
      # scope-fetching, never an ability rule.
      register_resource(:seller_profile, group: :access, subjects: -> { [:seller_profile] },
                                         audiences: %i[seller])

      register_resource(:dashboard, group: :analytics, subjects: -> { [:dashboard] },
                                    write: false, audiences: %i[seller])
    end
    # rubocop:enable Metrics/MethodLength
  end
end
