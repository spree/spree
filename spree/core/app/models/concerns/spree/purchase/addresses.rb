module Spree
  module Purchase
    # The full address surface shared by Spree::Cart and Spree::Order:
    # the bill/ship associations and their public aliases, default filling
    # from the customer's saved addresses, address-row deduplication on
    # write, ownership-guarded address_id assignment, promotion of checkout
    # addresses to the customer's defaults, and the ship→bill cloning
    # predicate. The shipping address is canonical: use_shipping copies it
    # onto the billing address; the reverse use_billing direction is a
    # deprecated 6.1-removal bridge. Clone callbacks are wired per model.
    module Addresses
      extend ActiveSupport::Concern

      included do
        belongs_to :bill_address, class_name: 'Spree::Address', optional: true, dependent: :destroy
        belongs_to :ship_address, class_name: 'Spree::Address', optional: true, dependent: :destroy

        # The writers these generate are shadowed by the hand-written ones
        # below, which deduplicate address rows. The declarations still earn
        # their place: ParamsNormalizer reads nested_attributes_options to
        # rewrite an incoming `ship_address` hash to `ship_address_attributes`,
        # so dropping them sends a raw hash to the belongs_to writer instead.
        accepts_nested_attributes_for :bill_address
        accepts_nested_attributes_for :ship_address

        alias_method :billing_address, :bill_address
        alias_method :billing_address=, :bill_address=
        alias_attribute :billing_address_id, :bill_address_id
        alias_method :shipping_address, :ship_address
        alias_method :shipping_address=, :ship_address=
        alias_attribute :shipping_address_id, :ship_address_id

        alias_method :shipping_address_attributes=, :ship_address_attributes=
        alias_method :billing_address_attributes=, :bill_address_attributes=

        attr_accessor :temporary_address, :use_shipping
        attr_reader :use_billing

        before_validation :clone_billing_address, if: :use_billing?
        before_validation :clone_shipping_address, if: :use_shipping?
      end

      # @return [Boolean]
      def shipping_eq_billing_address?
        bill_address == ship_address
      end

      # Whether checkout must collect a customer shipping address. Selected
      # delivery methods are the source of truth — their fulfillment
      # providers decide (digital and pickup deliveries need none). Before
      # any selection, falls back to the record's merchant-pickup intent and
      # the items' possible fulfillment types, matched against the store's
      # configured address-requiring delivery methods.
      #
      # @return [Boolean]
      def shipping_address_required?
        selected_methods = fulfillments.filter_map(&:delivery_method)
        return selected_methods.any?(&:requires_address?) if selected_methods.any?

        return false if preferred_stock_location_id.present?

        # An address is needed when any item's profile ships to one —
        # answered by the profile kind, resolved once per profile.
        profile_requires_address = Hash.new do |cache, profile|
          cache[profile] = profile.present? && profile.requires_shipping_address?
        end

        # Both profile paths are preloaded: the variant's own override, and the
        # product's for the variants that inherit it.
        line_items.includes(variant: [:delivery_profile, { product: :delivery_profile }]).any? do |line_item|
          profile_requires_address[line_item.variant&.resolved_delivery_profile]
        end
      end

      # @deprecated The shipping address is canonical — use +use_shipping+ to
      #   copy it onto the billing address. Removed in 6.1.
      def use_billing=(value)
        Spree::Deprecation.warn('use_billing is deprecated and will be removed in Spree 6.1. The shipping address comes first — use use_shipping to copy it onto the billing address.')
        @use_billing = value
      end

      # @deprecated See {#use_billing=}; removed in 6.1.
      # @return [Boolean]
      def use_billing?
        use_billing.in?([true, 'true', '1'])
      end

      # @return [Boolean]
      def use_shipping?
        use_shipping.in?([true, 'true', '1'])
      end

      # Fills any blank bill/ship address from the customer's valid saved
      # defaults. The ship address is skipped when no physical delivery is
      # required, so shipping-address validations never fire on digital-only
      # purchases.
      #
      # @return [void]
      def assign_default_addresses!
        return unless customer

        self.bill_address = customer.bill_address if !bill_address_id && customer.bill_address&.valid?
        # Skip the ship address only for all-digital records to avoid
        # triggering shipping-address validations (an empty record still
        # gets one — items usually arrive after the address).
        self.ship_address = customer.ship_address if !ship_address_id && customer.ship_address&.valid? && !digital?
      end

      # Copies the ship address onto the bill address and promotes it to the
      # customer's default bill address.
      #
      # @return [true]
      def clone_shipping_address
        self.bill_address = ship_address if ship_address
        customer.bill_address = ship_address if should_assign_user_default_address?(ship_address)
        true
      end

      # Copies the bill address onto the ship address and promotes it to the
      # customer's default ship address.
      #
      # @deprecated The shipping address is canonical (see {#use_billing=});
      #   removed in 6.1 together with the use_billing bridge.
      # @return [true]
      def clone_billing_address
        self.ship_address = bill_address if bill_address
        customer.ship_address = bill_address if should_assign_user_default_address?(bill_address)
        true
      end

      # Ownership-guarded writer: the id is applied only when the address is
      # one this purchase may ship to — the buyer's own book, or the book of
      # the company it is for. Anything else, including any id on a guest
      # record, resolves to nil.
      #
      # @param id [Integer, String, nil]
      def bill_address_id=(id)
        return if bill_address_id == id

        self['bill_address_id'] = selectable_address(id)&.id
        reset_bill_address
      end

      # Deduplicating writer: reuses or updates an existing address row when
      # possible, then promotes the result to the customer's default bill
      # address.
      #
      # @param attributes [Hash, ActionController::Parameters]
      def bill_address_attributes=(attributes)
        self.bill_address = update_or_create_address(attributes)
        customer.bill_address = bill_address if should_assign_user_default_address?(bill_address)
      end

      # Ownership-guarded writer — see {#bill_address_id=}.
      #
      # @param id [Integer, String, nil]
      def ship_address_id=(id)
        return if ship_address_id == id

        self['ship_address_id'] = selectable_address(id)&.id
        reset_ship_address
      end

      # Deduplicating writer — see {#bill_address_attributes=}. Quick-checkout
      # (wallet) addresses are never promoted to defaults, and an unpersisted
      # quick-checkout address is discarded.
      #
      # @param attributes [Hash, ActionController::Parameters]
      def ship_address_attributes=(attributes)
        self.ship_address = update_or_create_address(attributes)
        customer.ship_address = ship_address if should_assign_user_default_address?(ship_address)
        self.ship_address = nil if quick_checkout_address?(attributes[:quick_checkout]) && !ship_address.persisted?
      end

      private

      # The address behind an id a client may select, or nil when the id names
      # one this purchase has no business shipping to.
      #
      # Two books qualify. The buyer's own is the ordinary case. The company's
      # is the B2B one: a purchase for a node ships to that node's sites, and
      # to its ancestors' — the same self-and-ancestors chain the node's
      # default address is prefilled from, so a division can pick the
      # headquarters address it already inherits.
      #
      # Standing is not re-checked here: a cart cannot name a company its
      # customer lacks standing over, so reaching this point already means the
      # buyer may act for the node.
      #
      # @param id [Integer, String, nil]
      # @return [Spree::Address, nil]
      def selectable_address(id)
        address = ::Spree::Address.find_by(id: id)
        return nil if address.nil?

        return address if customer_id.present? && address.customer_owned? && address.owner_id == customer_id

        company = resolved_company
        return nil if company.nil? || address.owner_type != 'Spree::Company'

        company.self_and_ancestors.any? { |node| node.id == address.owner_id } ? address : nil
      end

      def update_or_create_address(attributes = {})
        return if attributes.blank?

        attributes.transform_values!(&:presence)
        attributes = attributes.to_h.symbolize_keys

        default_address_scope = customer ? customer.addresses : ::Spree::Address.where(owner_id: nil)
        default_address = default_address_scope.find_by(id: attributes[:id])

        if default_address&.editable?
          default_address.update(attributes)

          return default_address
        end

        attributes = attributes.except(:id, :updated_at, :created_at)
        attributes[:owner] = customer

        ::Spree::Address.find_duplicate(attributes) || ::Spree::Address.create(attributes)
      end

      def quick_checkout_address?(quick_checkout_param)
        quick_checkout_param.present? ? quick_checkout_param.to_b : false
      end

      def should_assign_user_default_address?(address)
        customer.present? && address.present? && address.valid? && address.customer_owner == customer && !address.quick_checkout?
      end
    end
  end
end
