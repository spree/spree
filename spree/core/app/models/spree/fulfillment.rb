require 'ostruct'

module Spree
  class Fulfillment < Spree.base_class
    has_prefix_id :ful

    include Spree::DerivedNumber
    derives_number infix: 'F'
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::StorePreferences
    if defined?(Spree::Security::Shipments)
      include Spree::Security::Shipments
    end
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end
    include Spree::Fulfillment::CustomEvents

    publishes_lifecycle_events

    with_options inverse_of: :fulfillments do
      belongs_to :address, class_name: 'Spree::Address', optional: true
      belongs_to :order, class_name: 'Spree::Order', touch: true, optional: true
      belongs_to :cart, class_name: 'Spree::Cart', optional: true
    end
    belongs_to :stock_location, -> { with_deleted }, class_name: 'Spree::StockLocation'

    with_options dependent: :delete_all do
      has_many :fulfillment_items, class_name: 'Spree::FulfillmentItem', inverse_of: :fulfillment
      has_many :delivery_rates, -> { order(:cost) }, class_name: 'Spree::DeliveryRate'
    end
    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy, inverse_of: :fulfillment
    has_many :discounts, class_name: 'Spree::Discount', dependent: :destroy, inverse_of: :fulfillment
    has_many :fees, class_name: 'Spree::Fee', dependent: :destroy, inverse_of: :fulfillment
    has_many :delivery_methods, through: :delivery_rates
    has_many :variants, through: :fulfillment_items
    has_one :selected_delivery_rate, -> { where(selected: true).order(:cost) }, class_name: 'Spree::DeliveryRate'

    after_save :update_adjustments

    before_validation :set_cost_zero_when_nil
    before_save :detect_tracking_carrier, if: -> { will_save_change_to_tracking? && tracking_carrier.blank? }

    validates :stock_location, presence: true
    validate :exactly_one_owner

    attr_accessor :special_instructions

    accepts_nested_attributes_for :address
    accepts_nested_attributes_for :fulfillment_items

    # unfulfilled/fulfilled/delivered/canceled scopes + predicates come from
    # has_status below. These are the ones it cannot generate.
    #
    # @deprecated legacy names — removed in 6.1
    scope :shipped, -> { fulfilled }
    scope :pending, -> { unfulfilled }
    scope :ready, -> { unfulfilled }
    scope :ready_or_pending, -> { unfulfilled }
    # Everything that has left the merchant's hands, whether or not the carrier
    # has confirmed receipt — the natural set for reporting and for skipping
    # work that only applies to packages still on the shelf.
    scope :fulfilled_or_delivered, -> { where(status: %w(fulfilled delivered)) }
    scope :trackable, -> { where("tracking IS NOT NULL AND tracking != ''") }
    scope :with_state, ->(*s) { where(status: s) }
    # sort by most recent fulfilled_at, falling back to created_at. add "id desc" to make specs that involve this scope more deterministic.
    scope :reverse_chronological, -> { order(Arel.sql("coalesce(#{table_name}.fulfilled_at, #{table_name}.created_at) desc"), id: :desc) }
    scope :valid, -> { where.not(status: :canceled) }
    scope :not_canceled, -> { where.not(status: 'canceled') }
    scope :shipped_but_canceled, -> { canceled.where.not(fulfilled_at: nil) }
    # This scope will select the delivery_method_id from the fulfillments' selected delivery rate
    scope :with_selected_delivery_method, lambda {
                                                 joins(:selected_delivery_rate).
                                                   where(Spree::DeliveryRate.arel_table[:delivery_method_id].not_eq(nil)).
                                                   select(Spree::DeliveryRate.arel_table[:delivery_method_id])
                                          }
    scope :digital_delivery, -> { joins(:delivery_methods).merge(Spree::DeliveryMethod.digital) }

    delegate :store, :currency, to: :owner

    # The exactly-one owner of this fulfillment — the cart during checkout,
    # the order after completion. New code must read +owner+, never assume
    # +order+.
    #
    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
    end

    # `store` is delegated to the owner, which raises when a fulfillment has
    # neither an order nor a cart yet.
    # @return [Spree::Store, nil]
    def preference_store
      owner&.store
    end

    # Bridge for legacy callers assigning +current_order+ (now a Spree::Cart)
    # to the order association — routes carts to the cart FK instead.
    def order=(record)
      if record.is_a?(Spree::Cart)
        self.cart = record
        super(nil)
      else
        super
      end
    end
    delegate :amount_in_cents, to: :display_cost

    # Statuses describe what the merchant did with the package — nothing else.
    # Payment and stock readiness used to be encoded here as pending/ready and
    # re-derived from the order on every recalculation, so a refund could move a
    # fulfillment backwards with no physical change. That gate now lives in
    # Spree::Fulfillments::Fulfill, where it can explain itself and be
    # overridden. Transitions belong to the workflows in
    # app/workflows/spree/fulfillments (docs/plans/6.0-fulfillment-and-delivery.md).
    include Spree::HasStatus
    has_status :unfulfilled, :fulfilled, :delivered, :canceled, default: :unfulfilled

    # Unlike returns and claims, fulfillments are built directly — by the stock
    # coordinator, by cart completion, by transfers — rather than always through
    # a creating workflow, so the default is applied here instead of being left
    # to each caller. This is what the machine's `initial:` used to do.
    after_initialize :apply_default_status, if: :new_record?

    # What the carrier reports, kept apart from the merchant lifecycle: a bounced
    # or damaged package changes this, never #status.
    TRACKING_STATUSES = %w(
      pre_transit in_transit out_for_delivery available_for_pickup
      delivered return_to_sender failure unknown
    ).freeze

    validates :tracking_status, inclusion: { in: TRACKING_STATUSES }, allow_blank: true

    # @deprecated Use {Spree::Fulfillments::Fulfill}; removed in 6.1.
    def ship(*args)
      Spree::Deprecation.warn('Spree::Fulfillment#ship is deprecated and will be removed in Spree 6.1. Use Spree::Fulfillments::Fulfill instead.')
      Spree.fulfillment_fulfill_workflow.call(fulfillment: self, **args.first.to_h)
    end
    alias ship! ship

    # @deprecated Use {#can_fulfill?}; removed in 6.1.
    def can_ship?
      Spree::Deprecation.warn('Spree::Fulfillment#can_ship? is deprecated and will be removed in Spree 6.1. Use #can_fulfill? instead.')
      can_fulfill?
    end

    # @deprecated Use {#fulfilled?}; removed in 6.1.
    def shipped?
      Spree::Deprecation.warn('Spree::Fulfillment#shipped? is deprecated and will be removed in Spree 6.1. Use #fulfilled? instead.')
      fulfilled?
    end

    # Whether this fulfillment may still be handed over. Composes the status
    # rule with the provider's own veto; the payment and stock side of the
    # question belongs to Spree::Fulfillments::Fulfill, which can report why.
    #
    # Stated negatively — anything that has not already gone out can go out —
    # so a status an extension adds before `fulfilled` (an `in_production`
    # stage, say) is fulfillable without overriding anything. Whether it
    # SHOULD go out yet is the fulfill workflow's validate hook's question.
    #
    # @return [Boolean]
    def can_fulfill?
      !fulfilled_or_delivered? && provider.can_fulfill?(self)
    end

    # Whether the package can still be recalled: anything that has neither
    # gone out nor already been recalled. Negative for the same reason as
    # {#can_fulfill?} — custom pre-handover statuses stay cancelable.
    #
    # @return [Boolean]
    def can_cancel?
      !fulfilled_or_delivered? && !canceled?
    end

    # @return [Boolean] whether a canceled fulfillment can be reinstated
    def can_resume?
      canceled?
    end

    # @return [Boolean] whether receipt can still be confirmed
    def can_mark_delivered?
      fulfilled?
    end

    # Everything that has left the merchant's hands. Reads better than
    # `fulfilled? || delivered?` at call sites that only care that the package
    # is gone.
    #
    # @return [Boolean]
    def fulfilled_or_delivered?
      fulfilled? || delivered?
    end
    # @deprecated the column is +status+ since 6.0
    alias_attribute :state, :status
    alias_attribute :shipped_at, :fulfilled_at
    after_save { @tracking_url = nil }
    # Legacy association names — removed in 6.1.
    has_many :inventory_units, class_name: 'Spree::FulfillmentItem', foreign_key: :fulfillment_id, inverse_of: :fulfillment, deprecated: true
    has_many :shipping_rates, -> { order(:cost) }, class_name: 'Spree::DeliveryRate', foreign_key: :fulfillment_id, deprecated: true
    has_one :selected_shipping_rate, -> { where(selected: true).order(:cost) }, class_name: 'Spree::DeliveryRate', foreign_key: :fulfillment_id, deprecated: true
    has_many :shipping_methods, through: :delivery_rates, source: :delivery_method, deprecated: true

    self.whitelisted_ransackable_attributes = ['number']

    extend DisplayMoney
    money_methods :cost, :discounted_cost, :final_price, :item_cost, :additional_tax_total, :included_tax_total, :tax_total, :promo_total
    alias display_amount display_cost
    alias_attribute :discount_total, :promo_total
    alias display_discount_total display_promo_total

    normalizes :tracking, with: ->(value) { value&.to_s&.squish&.presence }

    # Returns the shipment number and shipping method name
    #
    # @return [String]
    def name
      [number, delivery_method&.name].compact.join(' ').strip
    end

    def amount
      cost
    end

    # Strict decimal bridge for string input — raises ArgumentError on
    # malformed values instead of letting Rails' cast silently truncate
    # ("12 boxes" would otherwise become 12.0). Blank strings cast to nil,
    # matching the default Rails behavior.
    #
    # @param value [String, Numeric, nil]
    def cost=(value)
      value = value.blank? ? nil : BigDecimal(value.strip) if value.is_a?(String)
      super
    end

    def digital?
      delivery_method&.digital? || false
    end

    # @deprecated Use {#delivery_method}; removed in 6.1.
    def shipping_method
      Spree::Deprecation.warn('Spree::Fulfillment#shipping_method is deprecated and will be removed in Spree 6.1. Use #delivery_method instead.')
      delivery_method
    end

    def add_delivery_method(delivery_method, selected = false)
      delivery_rates.create(delivery_method: delivery_method, selected: selected, cost: cost)
    end

    # @deprecated Use {#add_delivery_method}; removed in 6.1.
    def add_shipping_method(delivery_method, selected = false)
      Spree::Deprecation.warn('Spree::Fulfillment#add_shipping_method is deprecated and will be removed in Spree 6.1. Use #add_delivery_method instead.')
      add_delivery_method(delivery_method, selected)
    end

    # @deprecated Cancel through {Spree::Fulfillments::Cancel}; removed in 6.1.
    #   Restocking and the provider call are workflow steps now, so this no
    #   longer runs as a transition callback. Kept only so a host app that
    #   called it directly keeps working for one release.
    def after_cancel
      Spree::Deprecation.warn('Spree::Fulfillment#after_cancel is deprecated and will be removed in Spree 6.1. Cancel through Spree::Fulfillments::Cancel instead.')
      manifest.each { |item| manifest_restock(item) }
      provider.cancel_fulfillment(self)
    end

    # @deprecated Resume through {Spree::Fulfillments::Resume}; removed in 6.1.
    def after_resume
      Spree::Deprecation.warn('Spree::Fulfillment#after_resume is deprecated and will be removed in Spree 6.1. Resume through Spree::Fulfillments::Resume instead.')
      manifest.each { |item| manifest_unstock(item) }
    end

    # Returns true if the shipment has any backordered inventory units
    #
    # @return [Boolean]
    def backordered?
      fulfillment_items.any?(&:backordered?)
    end

    # Returns true if the shipment is tracked
    #
    # @return [Boolean]
    def tracked?
      tracking.present? || tracking_url.present?
    end

    # Returns true if the shipment is shippable
    #
    # @return [Boolean]
    def shippable?
      can_fulfill? && (tracked? || digital?)
    end

    # Returns true if not all of the shipment's line items are fully shipped
    #
    # @return [Boolean]
    def partial?
      manifest.any? do |manifest_item|
        line_item = manifest_item.line_item
        line_item.quantity > manifest_item.quantity
      end
    end

    def discounted_cost
      cost + promo_total
    end
    alias discounted_amount discounted_cost

    # Returns the amount this shipment is taxed on: its discounted cost,
    # never negative (stacked shipping promotions can push discounted_cost
    # below zero). Whole-order promotions are not allocated to shipments.
    #
    # @return [BigDecimal]
    def taxable_basis
      [discounted_cost, BigDecimal(0)].max
    end

    def final_price
      cost + adjustment_total
    end
    alias total final_price
    alias display_total display_final_price

    def final_price_with_items
      item_cost + final_price
    end

    def free?
      return true if final_price == BigDecimal(0)

      with_free_shipping_promotion?
    end

    # Returns true if the shipment has a free shipping promotion applied
    #
    # @return [Boolean]
    def with_free_shipping_promotion?
      discounts.promotion.exists?
    end

    def finalize!
      fulfillment_items.finalize_units!
      after_resume
    end

    def include?(variant)
      inventory_units_for(variant).present?
    end

    def inventory_units_for(variant)
      fulfillment_items.where(variant_id: variant.id)
    end

    def inventory_units_for_item(line_item, variant = nil)
      fulfillment_items.where(line_item_id: line_item.id, variant_id: line_item.variant_id || variant.id)
    end

    # Returns the total quantity of all line items in the shipment
    def item_quantity
      manifest.sum(&:quantity)
    end

    # Returns the cost of the shipment
    #
    # @return [BigDecimal]
    def item_cost
      manifest.map { |m| (m.line_item.price + (m.line_item.adjustment_total / m.line_item.quantity)) * m.quantity }.sum
    end

    # Returns the weight of the shipment
    #
    # @return [BigDecimal]
    def item_weight
      manifest.map { |m| m.line_item.item_weight }.sum
    end

    # Returns the weight unit of the shipment
    #
    # @return [String]
    def weight_unit
      manifest.first.line_item.weight_unit
    end

    def line_items
      fulfillment_items.includes(:line_item).map(&:line_item).uniq
    end

    ManifestItem = Struct.new(:line_item, :variant, :quantity, :states)

    def manifest
      # Grouping by the ID means that we don't have to call out to the association accessor
      # This makes the grouping by faster because it results in less SQL cache hits.
      fulfillment_items.group_by(&:variant_id).flat_map do |_variant_id, units|
        units.group_by(&:line_item_id).filter_map do |_line_item_id, units|
          line_item = units.first.line_item
          # Defensively skip orphaned inventory units (line item destroyed
          # without cascading) so a single bad row doesn't crash callers that
          # rely on line_item being present (item_cost, item_weight, the admin
          # shipment manifest view, etc.).
          next if line_item.nil?

          states = {}
          units.group_by(&:status).each { |status, iu| states[status] = iu.sum(&:quantity) }

          variant = units.first.variant
          ManifestItem.new(line_item, variant, units.sum(&:quantity), states)
        end
      end
    end

    # Payments whose method charges on dispatch. A method set to charge
    # manually is never swept up by a dispatch — that is the whole point of
    # choosing it — so it is left for staff to capture.
    #
    # Read through +owner+ rather than +order+: a fulfillment can still belong
    # to a cart, and both carry pending_payments.
    #
    # @return [Array<Spree::Payment>]
    def payments_to_capture_on_dispatch
      Array(owner&.pending_payments).select { |payment| payment.payment_method&.capture_on_dispatch? }
    end

    def process_order_payments
      pending_payments = payments_to_capture_on_dispatch.
                         sort_by(&:uncaptured_amount).reverse

      shipment_to_pay = final_price_with_items
      payments_amount = 0

      payments_pool = pending_payments.each_with_object([]) do |payment, pool|
        break if payments_amount >= shipment_to_pay

        payments_amount += payment.uncaptured_amount
        pool << payment
      end

      payments_pool.each do |payment|
        capturable_amount = if payment.amount >= shipment_to_pay
                              shipment_to_pay
                            else
                              payment.amount
                            end

        cents = (capturable_amount * 100).to_i
        payment.capture!(cents)
        shipment_to_pay -= capturable_amount
      end
    end

    # @deprecated Use {#unfulfilled?}; removed in 6.1.
    def ready_or_pending?
      unfulfilled?
    end

    # @deprecated Use {#unfulfilled?}; removed in 6.1.
    def pending?
      unfulfilled?
    end

    # @deprecated Use {#unfulfilled?}; removed in 6.1.
    def ready?
      unfulfilled?
    end

    # @deprecated `ready_for_pickup` is not a status since 6.0 — for pickup
    # fulfillments `fulfilled` means "waiting at the counter". Removed in 6.1.
    def ready_for_pickup?
      fulfilled? && provider.class.pickup?
    end

    # @param audience [Symbol] {Spree::DeliveryMethod::STOREFRONT} (default)
    #   or {Spree::DeliveryMethod::BACKOFFICE}
    # @return [Array<Spree::DeliveryRate>]
    def refresh_rates(audience = DeliveryMethod::STOREFRONT)
      return delivery_rates if fulfilled?
      return [] unless can_get_rates?

      # StockEstimator.new assignment below will replace the current delivery_method
      original_shipping_method_id = delivery_method.try(:id)
      # A carrier method quotes several rates (one per service), so the
      # method id alone no longer identifies the customer's choice — capture
      # the selected rate's carrier service too.
      original_selection = selected_delivery_rate
      original_carrier = original_selection&.carrier
      original_service_level = original_selection&.service_level

      self.delivery_rates = Stock::Estimator.new(owner).
                            delivery_rates(to_package, audience)

      if delivery_method
        # Keep the previously chosen carrier service when it is still quoted,
        # then the previously chosen method, then the estimator's own pick
        # (the cheapest rate, already flagged selected) rather than leaving
        # the fulfillment unselected.
        selected_rate =
          if original_shipping_method_id && original_carrier
            delivery_rates.detect do |rate|
              rate.delivery_method_id == original_shipping_method_id &&
                rate.carrier == original_carrier &&
                rate.service_level == original_service_level
            end
          end
        selected_rate ||=
          if original_shipping_method_id
            delivery_rates.detect { |rate| rate.delivery_method_id == original_shipping_method_id }
          end
        selected_rate ||= delivery_rates.detect(&:selected)

        save!
        self.selected_shipping_rate_id = selected_rate.id if selected_rate
        reload
      end

      delivery_rates
    end

    # Public API v3 name for the selected rate (see docs/plans/6.0-fulfillment-and-delivery.md).
    #
    # @return [String, nil] the selected delivery rate's prefixed ID
    def selected_delivery_rate_id
      selected_delivery_rate&.prefixed_id
    end

    # Selects a delivery rate by its public prefixed ID (+dr_...+); raw IDs
    # are accepted for internal callers. The model owns this naming bridge so
    # API clients never deal with the legacy shipping-rate name.
    #
    # @param id [String, Integer] delivery rate prefixed or raw ID
    def selected_delivery_rate_id=(id)
      rate = Spree::PrefixedId.prefixed_id?(id) ? delivery_rates.find_by_prefix_id!(id) : delivery_rates.find(id)
      self.selected_shipping_rate_id = rate.id
    end

    def selected_shipping_rate_id
      selected_delivery_rate.try(:id)
    end

    def selected_shipping_rate_id=(id)
      # Explicitly updates the timestamp in order to bust cache dependent on "updated_at"
      delivery_rates.update_all(selected: false, updated_at: Time.current)
      delivery_rates.update(id, selected: true)
      save!
      # Reload associations to pick up the new selected shipping rate
      delivery_rates.reset
      association(:selected_delivery_rate).reset
      # Update shipment cost and owner totals only during checkout.
      # For completed orders, totals are managed separately (e.g., in tests or admin adjustments)
      return if owner.nil? || owner.completed?

      update_amounts
      reload # reload to pick up cost set by update_columns in update_amounts
      owner.set_fulfillments_cost
    end

    # +owner+ is the cart or order the units belong to. The item's order_id is
    # a completion-time denormalization (backorder processing joins through
    # it): during checkout it stays nil — writing a cart's id into an order
    # foreign key would silently link the item to whatever order shares that
    # id. Carts::Complete stamps the real order onto the copied items.
    def set_up_inventory(status, variant, owner, line_item, quantity = 1)
      return if quantity <= 0

      fulfillment_items.create(
        status: status,
        variant_id: variant.id,
        order_id: owner.is_a?(Spree::Order) ? owner.id : nil,
        line_item_id: line_item.id,
        quantity: quantity
      )
    end

    def shipped=(value)
      return unless value == '1' && fulfilled_at.nil?

      self.fulfilled_at = Time.current
    end

    # Returns the shipping method of the selected shipping rate
    #
    # @return [Spree::DeliveryMethod]
    def delivery_method
      selected_delivery_rate&.delivery_method || delivery_rates.first&.delivery_method
    end

    # The fulfillment provider strategy handling this fulfillment's
    # create/track/cancel mechanics — from the selected delivery method,
    # falling back to Manual when no method is selected.
    #
    # @return [Spree::FulfillmentProvider::Base]
    def provider
      delivery_method&.provider || Spree::FulfillmentProvider::Manual.new
    end

    # Commission base for multi-vendor include_shipping: the cost net of
    # fulfillment-attached discounts.
    #
    # @return [BigDecimal]
    def delivery_amount
      cost + discounts.sum(:amount)
    end

    # Returns the tax category of the selected shipping rate
    #
    # @return [Spree::TaxCategory]
    def tax_category
      selected_delivery_rate.try(:tax_rate).try(:tax_category)
    end

    # Returns the tax category ID of the selected shipping rate
    #
    # @return [Integer]
    def tax_category_id
      selected_delivery_rate.try(:tax_rate).try(:tax_category_id)
    end

    # Only one of either included_tax_total or additional_tax_total is set
    # This method returns the total of the two. Saves having to check if
    # tax is included or additional.
    def tax_total
      included_tax_total + additional_tax_total
    end

    def to_package
      package = Stock::Package.new(stock_location)
      package.owner = owner
      fulfillment_items.includes(:variant).joins(:variant).group_by(&:status).each do |status, units|
        package.add_multiple units, status.to_sym
      end
      package
    end

    # External systems (3PLs, courier APIs) often hand over a complete
    # tracking link rather than a bare tracking code — returned as-is
    # instead of being templated into the delivery method's tracking URL.
    #
    # @return [String, nil]
    # The public page where this parcel can be followed, best answer first:
    #
    # 1. The tracking value is already a link — pasted in whole.
    # 2. The provider that bought the label knows its own tracker page.
    # 3. The carrier pinned on this fulfillment (picked or detected) has a
    #    registered tracking page.
    # 4. The delivery method's configured format string, or detection from the
    #    number's format — the legacy path, still right for single-carrier
    #    methods.
    #
    # @return [String, nil]
    def tracking_url
      return if tracking.blank?

      @tracking_url ||= if tracking.start_with?('https://', 'http://')
                          tracking
                        else
                          provider.tracking_url(self).presence ||
                            carrier_tracking_url.presence ||
                            delivery_method&.build_tracking_url(tracking).presence ||
                            detected_tracking_url
                        end
    end

    # The pinned carrier's display name, for storefronts and admin UIs
    # showing "InPost: 421432" rather than a bare number.
    #
    # @return [String, nil]
    def tracking_carrier_name
      return if tracking_carrier.blank?

      Spree.tracking_carriers.dig(tracking_carrier, :name) || tracking_carrier.titleize
    end

    def update_amounts
      if selected_delivery_rate && cost != selected_delivery_rate.cost
        # Typed adjustment columns are refreshed by the order recalculation.
        update_columns(cost: selected_delivery_rate.cost, updated_at: Time.current)
      end
    end

    # @deprecated No-op since 6.0; removed in 6.1.
    #
    # This re-derived the status from the order's payment state on every order
    # recalculation, which is what made a fulfillment move backwards when a
    # refund landed. A fulfillment's status now only changes when a workflow
    # changes it, so there is nothing left to refresh.
    def update!(*args)
      # Only the legacy `update!(order)` form is dead. Anything else is
      # ActiveRecord's own update! — a Hash of attributes — which workflows
      # rely on to write the status.
      return super unless args.one? && (args.first.is_a?(Spree::Order) || args.first.is_a?(Spree::Cart))

      Spree::Deprecation.warn('Spree::Fulfillment#update!(order) is a no-op since Spree 6.0 and will be removed in 6.1. Fulfillment statuses change through Spree::Fulfillments workflows.')
      true
    end

    def transfer_to_location(variant, quantity, stock_location)
      transfer_to_shipment(
        variant,
        quantity,
        order.shipments.build(stock_location: stock_location)
      )
    end

    def transfer_to_shipment(variant, quantity, shipment_to_transfer_to)
      Spree::FulfillmentChanger.new(
        current_stock_location: stock_location,
        desired_stock_location: shipment_to_transfer_to.stock_location,
        current_shipment: self,
        desired_shipment: shipment_to_transfer_to,
        variant: variant,
        quantity: quantity
      )
    end

    private

    # Inlined from the removed ShipmentHandler (its name-constantize factory
    # could never match a real subclass); FulfillmentProvider takes over the
    # type-specific mechanics in the provider wave.
    def after_fulfill
      fulfillment_items.each(&:ship!)
      process_order_payments
      touch :fulfilled_at
      run_provider_create_fulfillment
      update_order_fulfillment_status
    end

    # Lets the provider perform its dispatch mechanics; tracking data it
    # returns is persisted unless an admin already entered one.
    def run_provider_create_fulfillment
      result = provider.create_fulfillment(self)
      return unless result.is_a?(Hash)

      new_tracking = result[:tracking_number].presence
      update_column(:tracking, new_tracking) if new_tracking && tracking.blank?
    end

    def update_order_fulfillment_status
      return if order.nil?

      order.update_statuses!
    end

    # publish_shipment_shipped_event, publish_shipment_canceled_event, and
    # publish_shipment_resumed_event are defined in Spree::Fulfillment::CustomEvents

    def can_get_rates?
      return true unless owner&.shipping_address_required?

      owner.ship_address&.valid?
    end

    def manifest_restock(item)
      if item.states['on_hand'].to_i.positive?
        stock_location.restock item.variant, item.states['on_hand'], self
      end

      if item.states['backordered'].to_i.positive?
        stock_location.restock_backordered item.variant, item.states['backordered']
      end
    end

    def manifest_unstock(item)
      stock_location.unstock(item.variant, item.quantity, self) if item.variant.track_inventory?
    end

    def set_cost_zero_when_nil
      self.cost = 0 unless cost
    end

    def apply_default_status
      self.status ||= self.class.default_status
    end

    def carrier_tracking_url
      template = Spree.tracking_carriers.dig(tracking_carrier.to_s, :url)
      template&.gsub(':tracking', ERB::Util.url_encode(tracking))
    end

    def detected_tracking_url
      service = Spree.tracking_number_service.new(tracking.upcase)
      service.tracking_url if service.valid?
    end

    # Numbers from the big carriers encode who they belong to; pinning the
    # detected carrier means the badge and the URL survive even when the
    # merchant only pasted a number. Only fills a blank — a merchant's
    # explicit pick, or a provider's, is never second-guessed.
    def detect_tracking_carrier
      return if tracking.blank? || tracking.start_with?('https://', 'http://')

      service = Spree.tracking_number_service.new(tracking.upcase)
      self.tracking_carrier = service.tracking.courier_code.to_s if service.valid?
    end

    def exactly_one_owner
      errors.add(:base, Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end

    def update_adjustments
      # A cost change shifts discount and tax bases — rebuild through the
      # order-level recalculation. Creation is excluded (the surrounding flow
      # runs the updater itself; recursing mid-assignment breaks collection
      # replacement) and completed orders are frozen.
      return if previously_new_record?

      owner.recalculate_totals! if saved_change_to_cost? && status != 'fulfilled' && owner&.persisted? && !owner.completed?
    end
  end
end
