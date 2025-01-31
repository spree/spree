require 'ostruct'

module Spree
  class Shipment < Spree.base_class
    include Spree::Core::NumberGenerator.new(prefix: 'H', length: 11)
    include Spree::NumberIdentifier
    include Spree::NumberAsParam
    include Spree::Metadata
    if defined?(Spree::Security::Shipments)
      include Spree::Security::Shipments
    end
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end
    include Spree::Shipment::Emails
    include Spree::Shipment::Webhooks

    with_options inverse_of: :shipments do
      belongs_to :address, class_name: 'Spree::Address'
      belongs_to :order, class_name: 'Spree::Order', touch: true
    end
    belongs_to :stock_location, -> { with_deleted }, class_name: 'Spree::StockLocation'

    with_options dependent: :delete_all do
      has_many :adjustments, as: :adjustable
      has_many :inventory_units, inverse_of: :shipment
      has_many :shipping_rates, -> { order(:cost) }
      has_many :state_changes, as: :stateful
    end
    has_many :shipping_methods, through: :shipping_rates
    has_many :variants, through: :inventory_units
    has_one :selected_shipping_rate, -> { where(selected: true).order(:cost) }, class_name: Spree::ShippingRate.to_s

    after_save :update_adjustments

    before_validation :set_cost_zero_when_nil

    validates :stock_location, presence: true

    attr_accessor :special_instructions

    accepts_nested_attributes_for :address
    accepts_nested_attributes_for :inventory_units

    scope :pending, -> { with_state('pending') }
    scope :ready,   -> { with_state('ready') }
    scope :shipped, -> { with_state('shipped') }
    scope :trackable, -> { where("tracking IS NOT NULL AND tracking != ''") }
    scope :with_state, ->(*s) { where(state: s) }
    # sort by most recent shipped_at, falling back to created_at. add "id desc" to make specs that involve this scope more deterministic.
    scope :reverse_chronological, -> { order(Arel.sql('coalesce(spree_shipments.shipped_at, spree_shipments.created_at) desc'), id: :desc) }
    scope :valid, -> { where.not(state: :canceled) }
    scope :canceled, -> { with_state('canceled') }
    scope :not_canceled, -> { where.not(state: 'canceled') }
    scope :shipped_but_canceled, -> { canceled.where.not(shipped_at: nil) }
    # This scope will select the shipping_method_id from the shipments' selected shipping rate
    scope :with_selected_shipping_method, lambda {
                                                 joins(:selected_shipping_rate).
                                                   where(Spree::ShippingRate.arel_table[:shipping_method_id].not_eq(nil)).
                                                   select(Spree::ShippingRate.arel_table[:shipping_method_id])
                                               }

    delegate :store, :currency, to: :order
    delegate :amount_in_cents, to: :display_cost

    # shipment state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: :pending, use_transactions: false do
      event :ready do
        transition from: :pending, to: :ready, if: lambda { |shipment|
          # Fix for #2040
          shipment.determine_state(shipment.order) == 'ready'
        }
      end

      event :pend do
        transition from: :ready, to: :pending
      end

      event :ship do
        transition from: %i(ready canceled), to: :shipped
      end
      after_transition to: :shipped, do: [:after_ship, :send_shipment_shipped_webhook]

      event :cancel do
        transition to: :canceled, from: %i(pending ready)
      end
      after_transition to: :canceled, do: :after_cancel

      event :resume do
        transition from: :canceled, to: :ready, if: lambda { |shipment|
          shipment.determine_state(shipment.order) == 'ready'
        }
        transition from: :canceled, to: :pending
      end
      after_transition from: :canceled, to: %i(pending ready shipped), do: :after_resume

      after_transition do |shipment, transition|
        shipment.state_changes.create!(
          previous_state: transition.from,
          next_state: transition.to,
          name: 'shipment'
        )
      end
    end

    self.whitelisted_ransackable_attributes = ['number']

    extend DisplayMoney
    money_methods :cost, :discounted_cost, :final_price, :item_cost, :additional_tax_total, :included_tax_total, :tax_total
    alias display_amount display_cost

    auto_strip_attributes :tracking

    # Returns the shipment number and shipping method name
    #
    # @return [String]
    def name
      [number, shipping_method&.name].compact.join(' ').strip
    end

    def amount
      cost
    end

    def add_shipping_method(shipping_method, selected = false)
      shipping_rates.create(shipping_method: shipping_method, selected: selected, cost: cost)
    end

    def after_cancel
      manifest.each { |item| manifest_restock(item) }
    end

    def after_resume
      manifest.each { |item| manifest_unstock(item) }
    end

    # Returns true if the shipment has any backordered inventory units
    #
    # @return [Boolean]
    def backordered?
      inventory_units.any?(&:backordered?)
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
      can_ship? && tracked?
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

    # Determines the appropriate +state+ according to the following logic:
    #
    # pending    unless order is complete and +order.payment_state+ is +paid+
    # shipped    if already shipped (ie. does not change the state)
    # ready      all other cases
    def determine_state(order)
      return 'canceled' if canceled? || order.canceled?
      return 'pending' unless order.can_ship?
      return 'pending' if inventory_units.any? &:backordered?
      return 'shipped' if shipped?

      order.paid? || Spree::Config[:auto_capture_on_dispatch] ? 'ready' : 'pending'
    end

    def discounted_cost
      cost + promo_total
    end
    alias discounted_amount discounted_cost

    def final_price
      cost + adjustment_total
    end

    def final_price_with_items
      item_cost + final_price
    end

    def free?
      return true if final_price == BigDecimal(0)

      return with_free_shipping_promotion?
    end

    def with_free_shipping_promotion?
      adjustments.promotion.any? { |p| p.source.type == 'Spree::Promotion::Actions::FreeShipping' }
    end

    def finalize!
      inventory_units.finalize_units!
      after_resume
    end

    def include?(variant)
      inventory_units_for(variant).present?
    end

    def inventory_units_for(variant)
      inventory_units.where(variant_id: variant.id)
    end

    def inventory_units_for_item(line_item, variant = nil)
      inventory_units.where(line_item_id: line_item.id, variant_id: line_item.variant_id || variant.id)
    end

    def item_cost
      manifest.map { |m| (m.line_item.price + (m.line_item.adjustment_total / m.line_item.quantity)) * m.quantity }.sum
    end

    def line_items
      inventory_units.includes(:line_item).map(&:line_item).uniq
    end

    ManifestItem = Struct.new(:line_item, :variant, :quantity, :states)

    def manifest
      # Grouping by the ID means that we don't have to call out to the association accessor
      # This makes the grouping by faster because it results in less SQL cache hits.
      inventory_units.group_by(&:variant_id).map do |_variant_id, units|
        units.group_by(&:line_item_id).map do |_line_item_id, units|
          states = {}
          units.group_by(&:state).each { |state, iu| states[state] = iu.sum(&:quantity) }

          line_item = units.first.line_item
          variant = units.first.variant
          ManifestItem.new(line_item, variant, units.sum(&:quantity), states)
        end
      end.flatten
    end

    def process_order_payments
      pending_payments = order.pending_payments.
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

    def ready_or_pending?
      ready? || pending?
    end

    def refresh_rates(shipping_method_filter = ShippingMethod::DISPLAY_ON_FRONT_END)
      return shipping_rates if shipped?
      return [] unless can_get_rates?

      # StockEstimator.new assignment below will replace the current shipping_method
      original_shipping_method_id = shipping_method.try(:id)

      self.shipping_rates = Stock::Estimator.new(order).
                            shipping_rates(to_package, shipping_method_filter)

      if shipping_method
        selected_rate = shipping_rates.detect do |rate|
          if original_shipping_method_id
            rate.shipping_method_id == original_shipping_method_id
          else
            rate.selected
          end
        end
        save!
        self.selected_shipping_rate_id = selected_rate.id if selected_rate
        reload
      end

      shipping_rates
    end

    def selected_shipping_rate_id
      selected_shipping_rate.try(:id)
    end

    def selected_shipping_rate_id=(id)
      # Explicitly updates the timestamp in order to bust cache dependent on "updated_at"
      shipping_rates.update_all(selected: false, updated_at: Time.current)
      shipping_rates.update(id, selected: true)
      save!
    end

    def set_up_inventory(state, variant, order, line_item, quantity = 1)
      return if quantity <= 0

      inventory_units.create(
        state: state,
        variant_id: variant.id,
        order_id: order.id,
        line_item_id: line_item.id,
        quantity: quantity
      )
    end

    def shipped=(value)
      return unless value == '1' && shipped_at.nil?

      self.shipped_at = Time.current
    end

    def shipping_method
      selected_shipping_rate&.shipping_method || shipping_rates.first&.shipping_method
    end

    def tax_category
      selected_shipping_rate.try(:tax_rate).try(:tax_category)
    end

    # Only one of either included_tax_total or additional_tax_total is set
    # This method returns the total of the two. Saves having to check if
    # tax is included or additional.
    def tax_total
      included_tax_total + additional_tax_total
    end

    def to_package
      package = Stock::Package.new(stock_location)
      inventory_units.includes(:variant).joins(:variant).group_by(&:state).each do |state, state_inventory_units|
        package.add_multiple state_inventory_units, state.to_sym
      end
      package
    end

    def tracking_url
      @tracking_url ||= shipping_method&.build_tracking_url(tracking)
    end

    def update_amounts
      if selected_shipping_rate
        update_columns(
          cost: selected_shipping_rate.cost,
          adjustment_total: adjustments.additional.map(&:update!).compact.sum,
          updated_at: Time.current
        )
      end
    end

    def update_attributes_and_order(params = {})
      Shipments::Update.call(shipment: self, shipment_attributes: params).success?
    end

    # Updates various aspects of the Shipment while bypassing any callbacks.  Note that this method takes an explicit reference to the
    # Order object.  This is necessary because the association actually has a stale (and unsaved) copy of the Order and so it will not
    # yield the correct results.
    def update!(order)
      old_state = state
      new_state = determine_state(order)
      update_columns(
        state: new_state,
        updated_at: Time.current
      )
      after_ship if new_state == 'shipped' && old_state != 'shipped'
    end

    def transfer_to_location(variant, quantity, stock_location)
      transfer_to_shipment(
        variant,
        quantity,
        order.shipments.build(stock_location: stock_location)
      )
    end

    def transfer_to_shipment(variant, quantity, shipment_to_transfer_to)
      Spree::FulfilmentChanger.new(
        current_stock_location: stock_location,
        desired_stock_location: shipment_to_transfer_to.stock_location,
        current_shipment: self,
        desired_shipment: shipment_to_transfer_to,
        variant: variant,
        quantity: quantity
      )
    end

    private

    def after_ship
      ShipmentHandler.factory(self).perform
    end

    def can_get_rates?
      order.ship_address&.valid?
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
      stock_location.unstock item.variant, item.quantity, self
    end

    def recalculate_adjustments
      Adjustable::AdjustmentsUpdater.update(self)
    end

    def set_cost_zero_when_nil
      self.cost = 0 unless cost
    end

    def update_adjustments
      recalculate_adjustments if saved_change_to_cost? && state != 'shipped'
    end
  end
end
