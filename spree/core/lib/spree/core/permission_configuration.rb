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

    # A registered catalog resource. Yields one or two grantable keys and maps
    # them to the CanCanCan subjects they cover.
    class Resource
      attr_reader :name, :group

      # @param name [Symbol] resource identifier (`:orders`)
      # @param group [Symbol] UI grouping for the permission pickers
      # @param subjects [Proc, Array] CanCanCan subjects covered by this
      #   resource; pass a lambda so model classes resolve lazily
      # @param write [Boolean] whether a `write_<name>` key exists
      def initialize(name:, group:, subjects:, write: true)
        @name = name.to_sym
        @group = group.to_sym
        @subjects = subjects
        @write = write
      end

      # @return [Boolean]
      def write?
        @write
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
    # @return [Resource]
    def register_resource(name, group:, subjects:, write: true)
      # `read_all` / `write_all` are the API-key wildcard aliases — a resource
      # named `all` would silently mint keys that grant the whole catalog.
      raise ArgumentError, "the permission resource name 'all' is reserved" if name.to_s == 'all'

      resource = Resource.new(name: name, group: group, subjects: subjects, write: write)
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
      register_resource(:orders, group: :orders, subjects: -> {
        [Spree::Order, Spree::LineItem, Spree::TaxLine, Spree::Discount, Spree::Fee,
         Spree::Return, Spree::Exchange, Spree::Claim, Spree::CustomField]
      })
      register_resource(:payments, group: :orders, subjects: -> { [Spree::Payment] })
      register_resource(:fulfillments, group: :orders, subjects: -> { [Spree::Fulfillment] })
      register_resource(:refunds, group: :orders, subjects: -> { [Spree::Refund] })
      register_resource(:gift_cards, group: :orders, subjects: -> {
        [Spree::GiftCard, Spree::GiftCardBatch]
      })
      register_resource(:store_credits, group: :orders, subjects: -> { [Spree::StoreCredit] })

      register_resource(:products, group: :catalog, subjects: -> {
        [Spree::Product, Spree::ProductType, Spree::Variant, Spree::OptionType,
         Spree::OptionValue, Spree::Price, Spree::PriceList, Spree::PriceRule,
         Spree::Asset, Spree::ProductPublication, Spree::CustomField]
      })
      register_resource(:categories, group: :catalog, subjects: -> {
        [Spree::Category, Spree::ProductCategory]
      })
      register_resource(:collections, group: :catalog, subjects: -> {
        [Spree::Collection, Spree::ProductCollection, Spree::CollectionRule]
      })
      register_resource(:stock, group: :catalog, subjects: -> {
        [Spree::StockItem, Spree::StockLocation, Spree::StockMovement,
         Spree::StockTransfer, Spree::StockReservation]
      })

      register_resource(:promotions, group: :marketing, subjects: -> {
        [Spree::Promotion, Spree::PromotionRule, Spree::PromotionAction,
         Spree::PromotionCategory, Spree::CouponCode, Spree::CustomField]
      })

      register_resource(:customers, group: :customers, subjects: -> {
        [Spree.customer_class, Spree::Address, Spree::CreditCard, Spree::CustomerGroup,
         Spree::CustomField]
      })

      register_resource(:settings, group: :settings, subjects: -> {
        [Spree::Store, Spree::PaymentMethod, Spree::Gateway, Spree::DeliveryMethod,
         Spree::DeliveryMethodRule, Spree::DeliveryZone, Spree::DeliveryZoneMember,
         Spree::StockLocation, Spree::DeliveryProfile, Spree::Zone, Spree::ZoneMember,
         Spree::Market, Spree::TaxCategory, Spree::TaxRate, Spree::AllowedOrigin,
         Spree::RefundReason, Spree::ReturnReason, Spree::ClaimReason, Spree::Channel,
         Spree::OrderRoutingRule, Spree::CustomFieldDefinition, Spree::Policy,
         Spree::StoreCreditCategory]
      })
      register_resource(:webhooks, group: :settings, subjects: -> {
        [Spree::WebhookEndpoint, Spree::WebhookDelivery]
      })
      register_resource(:integrations, group: :settings, subjects: -> { [Spree::Integration] })

      register_resource(:api_keys, group: :access, subjects: -> { [Spree::ApiKey] })
      register_resource(:staff, group: :access, subjects: -> {
        [Spree.admin_user_class, Spree::Invitation, Spree::Role, Spree::RoleUser]
      })

      register_resource(:dashboard, group: :analytics, subjects: -> { [:dashboard] }, write: false)
    end
    # rubocop:enable Metrics/MethodLength
  end
end
