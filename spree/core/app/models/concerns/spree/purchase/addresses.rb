module Spree
  module Purchase
    # The full address surface shared by Spree::Cart and Spree::Order:
    # the bill/ship associations and their public aliases, default filling
    # from the customer's saved addresses, address-row deduplication on
    # write, ownership-guarded address_id assignment and deletion, promotion
    # of checkout addresses to the customer's defaults, and the ship→bill cloning
    # predicate. The shipping address is canonical: use_shipping copies it
    # onto the billing address; the reverse use_billing direction is a
    # deprecated 6.1-removal bridge. Clone callbacks are wired per model.
    module Addresses
      extend ActiveSupport::Concern

      included do
        belongs_to :bill_address, class_name: 'Spree::Address', optional: true
        belongs_to :ship_address, class_name: 'Spree::Address', optional: true

        # Stands in for `dependent: :destroy`, which would take any attached
        # row down with the purchase. See {#owns_address?} for why only some
        # of them may go.
        after_destroy :destroy_own_addresses

        # The writers these generate are shadowed by the hand-written ones
        # below, which deduplicate address rows. The declarations still earn
        # their place: ParamsNormalizer reads nested_attributes_options to
        # rewrite an incoming `ship_address` hash to `ship_address_attributes`,
        # so dropping them sends a raw hash to the belongs_to writer instead.
        accepts_nested_attributes_for :bill_address
        accepts_nested_attributes_for :ship_address

        alias_method :billing_address=, :bill_address=
        alias_attribute :billing_address_id, :bill_address_id
        alias_method :shipping_address=, :ship_address=
        alias_attribute :shipping_address_id, :ship_address_id

        alias_method :shipping_address_attributes=, :ship_address_attributes=
        alias_method :billing_address_attributes=, :bill_address_attributes=

        attr_accessor :temporary_address, :use_shipping
        attr_reader :use_billing

        before_validation :clone_billing_address, if: :use_billing?
        before_validation :clone_shipping_address, if: :use_shipping?
      end

      # The public readers are what renderers ask for, one after the other,
      # so the first read loads both.
      #
      # @return [Spree::Address, nil]
      def billing_address
        load_both_addresses if persisted?
        bill_address
      end

      # @return [Spree::Address, nil]
      def shipping_address
        load_both_addresses if persisted?
        ship_address
      end

      # Whether both addresses are present and match. With neither present
      # there is nothing to call the same.
      #
      # @return [Boolean]
      def shipping_eq_billing_address?
        load_both_addresses
        ship_address.present? && bill_address == ship_address
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
        candidates = fulfillments.to_a
        if candidates.many? && candidates.all?(ActiveRecord::Base)
          ActiveRecord::Associations::Preloader.new(records: candidates, associations: { selected_delivery_rate: :delivery_method }).call
        end
        selected_methods = candidates.filter_map(&:delivery_method)
        return selected_methods.any?(&:requires_address?) if selected_methods.any?

        return false if preferred_stock_location_id.present?

        items_require_shipping_address?
      end

      # Whether delivery can be proposed yet: once there is a destination (a
      # shipping address, or a pickup intent for a purchase that never gets
      # one), or straight away when no item ships to an address. Quoted
      # without a destination, only pickup qualifies.
      #
      # @return [Boolean]
      def can_propose_deliveries?
        ship_address.present? || preferred_stock_location_id.present? || !items_require_shipping_address?
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

      # The address behind an id a client may select, or nil when the id names
      # one this purchase has no business shipping to. Takes a prefixed id or a
      # raw primary key, so the services that resolve a client-supplied id and
      # the writers below share one rule rather than each inventing their own.
      #
      # Two books qualify. The buyer's own is the ordinary case. The company's
      # is the B2B one: a purchase for a node ships to that node's sites, and
      # to its ancestors' — the same self-and-ancestors chain the node's
      # default address is prefilled from, so a division can pick the
      # headquarters address it already inherits.
      #
      # @param id [Integer, String, nil]
      # @return [Spree::Address, nil]
      def selectable_address(id)
        address = ::Spree::Address.not_deleted.find_by_param(id) || ::Spree::Address.not_deleted.find_by(id: id)
        return if address.nil?

        return address if customer_id.present? && address.customer_owned? && address.owner_id == customer_id

        company = readable_company
        return if company.nil? || address.owner_type != 'Spree::Company'

        company.self_and_ancestors.any? { |node| node.id == address.owner_id } ? address : nil
      end

      # Everything a checkout address picker may offer for this purchase: the
      # buyer's own book plus the book of the company it names, that node's
      # own entries and the ones it inherits, limited to the countries the
      # purchase's market sells to. A subset of what {#selectable_address}
      # accepts, so a picker built from it never offers an address the
      # checkout cannot deliver to.
      #
      # @return [ActiveRecord::Relation<Spree::Address>]
      def selectable_addresses
        books = []
        books << ::Spree::Address.not_deleted.where(owner_type: ::Spree.customer_class.to_s, owner_id: customer_id) if customer_id.present?
        books << readable_company&.address_book

        addresses = books.compact.reduce { |left, right| left.or(right) } || ::Spree::Address.none
        return addresses if market.nil?

        addresses.where(country_code: market.market_countries.select(:country_code))
      end

      # Whether an attached address row is this purchase's own to delete.
      #
      # Only the ownerless rows are: the one a guest typed in, and the
      # snapshot completion copies onto the order. Everything else is an entry
      # in somebody's address book — the buyer's, a company node's, a seller's
      # — which the purchase is merely pointing at. A cart may name a company
      # site every other member ships from, so taking an attached row down
      # with the cart would let one member empty the shared book.
      #
      # A business snapshot keeps its +owner_type+ to stay addressed to a
      # company rather than to a person, so ownership is the id, not the type.
      #
      # @param address [Spree::Address, nil]
      # @return [Boolean]
      def owns_address?(address)
        address.present? && address.owner_id.blank?
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
        self.bill_address = update_or_create_address(attributes, guest_row: guest_editable_address(bill_address, ship_address_id))
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
        self.ship_address = update_or_create_address(attributes, guest_row: guest_editable_address(ship_address, bill_address_id))
        customer.ship_address = ship_address if should_assign_user_default_address?(ship_address)
        self.ship_address = nil if quick_checkout_address?(attributes[:quick_checkout]) && !ship_address.persisted?
      end

      private

      # Both addresses live in one table, so they are fetched together — for
      # every record of a lazily preloaded list at once — instead of one
      # query per address.
      def load_both_addresses
        return if association(:bill_address).loaded? && association(:ship_address).loaded?

        ActiveRecord::Associations::Preloader.new(
          records: lazy_preload_context&.records || [self],
          associations: %i[bill_address ship_address]
        ).call
      end

      # The company whose book this purchase may read: only the one the
      # client named, never one inferred from a sole membership. A cart asks
      # again rather than trusting the column, which nothing clears when a
      # membership is revoked; an order's authority is staff or a completed
      # cart, so it keeps what it was given.
      #
      # @return [Spree::Company, nil]
      def readable_company
        return company if company.nil? || !is_a?(Spree::Cart)

        company if customer&.standing_for?(company)
      end

      # Both slots often hold the same row, so destroy it once.
      def destroy_own_addresses
        [bill_address, ship_address].compact.uniq.each do |address|
          address.destroy if owns_address?(address)
        end
      end

      def items_require_shipping_address?
        # Answered by the profile kind, resolved once per profile.
        profile_requires_address = Hash.new do |cache, profile|
          cache[profile] = profile.present? && profile.requires_shipping_address?
        end

        # On a list the association batches across the page, so a fresh
        # `includes` query would load every cart's items separately. Read
        # alone, both profile paths are preloaded: the variant's own override,
        # and the product's for the variants that inherit it.
        profile_paths = { variant: [:delivery_profile, { product: :delivery_profile }] }
        items = if !read_association_in_memory?(:line_items)
                  line_items.includes(profile_paths)
                elsif lazy_preload_context.nil?
                  line_items.tap { |loaded| ActiveRecord::Associations::Preloader.new(records: loaded.to_a, associations: profile_paths).call }
                else
                  line_items
                end

        items.any? do |line_item|
          profile_requires_address[line_item.variant&.resolved_delivery_profile]
        end
      end

      # Reuse never reaches past what the buyer already owns: a signed-in buyer
      # may name any entry of their own address book, and a guest — who keeps
      # no book — may only edit the row already in the slot being written.
      # Every other ownerless row is someone else's cart address or the
      # snapshot a placed order keeps, and reaching into those would let one
      # checkout read or rewrite another's address.
      def update_or_create_address(attributes = {}, guest_row: nil)
        return if attributes.blank?

        attributes.transform_values!(&:presence)
        attributes = attributes.to_h.symbolize_keys

        reusable_address = customer ? customer.addresses.find_by(id: attributes[:id]) : guest_row

        if reusable_address&.editable?
          reusable_address.update(attributes)

          return reusable_address
        end

        attributes = attributes.except(:id, :updated_at, :created_at)
        return ::Spree::Address.create(attributes) if customer.nil?

        attributes[:owner] = customer

        ::Spree::Address.find_duplicate(attributes) || ::Spree::Address.create(attributes)
      end

      # The row a guest write may edit in place rather than replace: the one
      # already in this slot, which is the only address a guest owns. Editing
      # it keeps a correction from leaving the row it corrected behind as an
      # orphan carrying someone's name and street.
      #
      # It is left alone while the other slot points at the same row — checkout
      # shares one row between the two whenever shipping is copied onto billing,
      # and editing it there would move the parcel as well as the invoice.
      #
      # @return [Spree::Address, nil]
      def guest_editable_address(address, other_slot_address_id)
        return nil if customer.present? || address.nil? || !address.persisted?
        return nil if address.owner_id.present? || address.id == other_slot_address_id

        address
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
