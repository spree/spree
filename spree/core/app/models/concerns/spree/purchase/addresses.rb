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

        address_requiring_types = store.delivery_methods.select(&:requires_address?).map(&:fulfillment_type).uniq
        return false if address_requiring_types.empty?

        line_items.includes(variant: :product).any? do |line_item|
          fulfillment_types = line_item.variant&.product&.fulfillment_types || ['shipping']
          (fulfillment_types & address_requiring_types).any?
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
        return unless user

        self.bill_address = user.bill_address if !bill_address_id && user.bill_address&.valid?
        # Skip the ship address only for all-digital records to avoid
        # triggering shipping-address validations (an empty record still
        # gets one — items usually arrive after the address).
        self.ship_address = user.ship_address if !ship_address_id && user.ship_address&.valid? && !digital?
      end

      # Copies the ship address onto the bill address and promotes it to the
      # customer's default bill address.
      #
      # @return [true]
      def clone_shipping_address
        self.bill_address = ship_address if ship_address
        user.bill_address = ship_address if should_assign_user_default_address?(ship_address)
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
        user.ship_address = bill_address if should_assign_user_default_address?(bill_address)
        true
      end

      # Ownership-guarded writer: the id is applied only when the address
      # belongs to the record's customer; anything else — including any id on
      # a guest record — resolves to nil.
      #
      # @param id [Integer, String, nil]
      def bill_address_id=(id)
        return if bill_address_id == id

        address = Spree::Address.find_by(id: id)
        # rubocop:disable Style/ConditionalAssignment
        if address && user_id.present? && address.user_id == user_id
          self['bill_address_id'] = address.id
        else
          self['bill_address_id'] = nil
        end
        # rubocop:enable Style/ConditionalAssignment
        reset_bill_address
      end

      # Deduplicating writer: reuses or updates an existing address row when
      # possible, then promotes the result to the customer's default bill
      # address.
      #
      # @param attributes [Hash, ActionController::Parameters]
      def bill_address_attributes=(attributes)
        self.bill_address = update_or_create_address(attributes)
        user.bill_address = bill_address if should_assign_user_default_address?(bill_address)
      end

      # Ownership-guarded writer — see {#bill_address_id=}.
      #
      # @param id [Integer, String, nil]
      def ship_address_id=(id)
        return if ship_address_id == id

        address = Spree::Address.find_by(id: id)
        # rubocop:disable Style/ConditionalAssignment
        if address && user_id.present? && address.user_id == user_id
          self['ship_address_id'] = address.id
        else
          self['ship_address_id'] = nil
        end
        # rubocop:enable Style/ConditionalAssignment
        reset_ship_address
      end

      # Deduplicating writer — see {#bill_address_attributes=}. Quick-checkout
      # (wallet) addresses are never promoted to defaults, and an unpersisted
      # quick-checkout address is discarded.
      #
      # @param attributes [Hash, ActionController::Parameters]
      def ship_address_attributes=(attributes)
        self.ship_address = update_or_create_address(attributes)
        user.ship_address = ship_address if should_assign_user_default_address?(ship_address)
        self.ship_address = nil if quick_checkout_address?(attributes[:quick_checkout]) && !ship_address.persisted?
      end

      private

      def update_or_create_address(attributes = {})
        return if attributes.blank?

        attributes.transform_values!(&:presence)
        attributes = attributes.to_h.symbolize_keys

        default_address_scope = user ? user.addresses : ::Spree::Address.where(user_id: nil)
        default_address = default_address_scope.find_by(id: attributes[:id])

        if default_address&.editable?
          default_address.update(attributes)

          return default_address
        end

        attributes = attributes.except(:id, :updated_at, :created_at)
        attributes[:user_id] = user&.id

        existing_address = find_existing_address(attributes)
        return existing_address if existing_address

        ::Spree::Address.create(attributes)
      end

      def find_existing_address(attributes)
        # Exclude virtual attributes that are handled by Address model callbacks
        address_attributes = attributes.except(:state_name, :country_iso, :state_abbr)
        state_name = attributes[:state_name]

        scope = Spree::Address.not_deleted.where(address_attributes)
        scope = scope.by_state_name_or_abbr(state_name) if state_name.present?
        scope.first
      end

      def quick_checkout_address?(quick_checkout_param)
        quick_checkout_param.present? ? quick_checkout_param.to_b : false
      end

      def should_assign_user_default_address?(address)
        user.present? && address.present? && address.valid? && address.user == user && !address.quick_checkout?
      end
    end
  end
end
