require 'ostruct'

module Spree
  class Shipment < ActiveRecord::Base
    belongs_to :order, class_name: 'Spree::Order', touch: true, inverse_of: :shipments
    belongs_to :address, class_name: 'Spree::Address', inverse_of: :shipments
    belongs_to :stock_location, class_name: 'Spree::StockLocation'

    has_many :shipping_rates, -> { order('cost ASC') }, dependent: :delete_all
    has_many :shipping_methods, through: :shipping_rates
    has_many :state_changes, as: :stateful
    has_many :inventory_units, dependent: :delete_all, inverse_of: :shipment
    has_many :adjustments, as: :adjustable, dependent: :delete_all

    after_save :update_adjustments

    before_validation :set_cost_zero_when_nil

    attr_accessor :special_instructions

    accepts_nested_attributes_for :address
    accepts_nested_attributes_for :inventory_units

    make_permalink field: :number, length: 11, prefix: 'H'

    scope :shipped, -> { with_state('shipped') }
    scope :ready,   -> { with_state('ready') }
    scope :pending, -> { with_state('pending') }
    scope :with_state, ->(*s) { where(state: s) }
    scope :trackable, -> { where("tracking IS NOT NULL AND tracking != ''") }

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
        transition from: :ready, to: :shipped
      end
      after_transition to: :shipped, do: :after_ship

      event :cancel do
        transition to: :canceled, from: [:pending, :ready]
      end
      after_transition to: :canceled, do: :after_cancel

      event :resume do
        transition from: :canceled, to: :ready, if: lambda { |shipment|
          shipment.determine_state(shipment.order) == :ready
        }
        transition from: :canceled, to: :pending, if: lambda { |shipment|
          shipment.determine_state(shipment.order) == :ready
        }
        transition from: :canceled, to: :pending
      end
      after_transition from: :canceled, to: [:pending, :ready], do: :after_resume

      after_transition do |shipment, transition|
        shipment.state_changes.create!(
          previous_state: transition.from,
          next_state:     transition.to,
          name:           'shipment',
        )
      end
    end

    def to_param
      number
    end

    def backordered?
      inventory_units.any? { |inventory_unit| inventory_unit.backordered? }
    end

    def ready_or_pending?
      self.ready? || self.pending?
    end

    def shipped=(value)
      return unless value == '1' && shipped_at.nil?
      self.shipped_at = Time.now
    end

    def shipping_method
      selected_shipping_rate.try(:shipping_method) || shipping_rates.first.try(:shipping_method)
    end

    def add_shipping_method(shipping_method, selected = false)
      shipping_rates.create(shipping_method: shipping_method, selected: selected, cost: cost)
    end

    def selected_shipping_rate
      shipping_rates.where(selected: true).first
    end

    def selected_shipping_rate_id
      selected_shipping_rate.try(:id)
    end

    def selected_shipping_rate_id=(id)
      shipping_rates.update_all(selected: false)
      shipping_rates.update(id, selected: true)
      self.save!
    end

    def tax_category
      selected_shipping_rate.try(:tax_rate).try(:tax_category)
    end

    def refresh_rates
      return shipping_rates if shipped?
      return [] unless can_get_rates?

      # StockEstimator.new assigment below will replace the current shipping_method
      original_shipping_method_id = shipping_method.try(:id)

      self.shipping_rates = Stock::Estimator.new(order).shipping_rates(to_package)

      if shipping_method
        selected_rate = shipping_rates.detect { |rate|
          rate.shipping_method_id == original_shipping_method_id
        }
        self.selected_shipping_rate_id = selected_rate.id if selected_rate
      end

      shipping_rates
    end

    def currency
      order ? order.currency : Spree::Config[:currency]
    end

    def display_cost
      Spree::Money.new(cost, { currency: currency })
    end
    alias display_amount display_cost

    def item_cost
      line_items.map(&:amount).sum
    end

    def discounted_cost
      cost + promo_total
    end
    alias discounted_amount discounted_cost

    # Only one of either included_tax_total or additional_tax_total is set
    # This method returns the total of the two. Saves having to check if 
    # tax is included or additional.
    def tax_total
      included_tax_total + additional_tax_total
    end

    def final_price
      discounted_cost + tax_total
    end

    def display_discounted_cost
      Spree::Money.new(discounted_cost, { currency: currency })
    end

    def display_final_price
      Spree::Money.new(final_price, { currency: currency })
    end

    def display_item_cost
      Spree::Money.new(item_cost, { currency: currency })
    end

    def editable_by?(user)
      !shipped?
    end

    ManifestItem = Struct.new(:line_item, :variant, :quantity, :states)

    def manifest
      # Grouping by the ID means that we don't have to call out to the association accessor
      # This makes the grouping by faster because it results in less SQL cache hits.
      inventory_units.group_by(&:variant_id).map do |variant_id, units|
        units.group_by(&:line_item_id).map do |line_item_id, units|

          states = {}
          units.group_by(&:state).each { |state, iu| states[state] = iu.count }

          line_item = units.first.line_item
          variant = units.first.variant
          ManifestItem.new(line_item, variant, units.length, states)
        end
      end.flatten
    end

    def line_items
      inventory_units.includes(:line_item).map(&:line_item).uniq
    end

    def finalize!
      InventoryUnit.finalize_units!(inventory_units)
      manifest.each { |item| manifest_unstock(item) }
    end

    def after_cancel
      manifest.each { |item| manifest_restock(item) }
    end

    def after_resume
      manifest.each { |item| manifest_unstock(item) }
    end

    # Updates various aspects of the Shipment while bypassing any callbacks.  Note that this method takes an explicit reference to the
    # Order object.  This is necessary because the association actually has a stale (and unsaved) copy of the Order and so it will not
    # yield the correct results.
    def update!(order)
      old_state = state
      new_state = determine_state(order)
      update_columns(
        state: new_state,
        updated_at: Time.now,
      )
      after_ship if new_state == 'shipped' and old_state != 'shipped'
    end

    # Determines the appropriate +state+ according to the following logic:
    #
    # pending    unless order is complete and +order.payment_state+ is +paid+
    # shipped    if already shipped (ie. does not change the state)
    # ready      all other cases
    def determine_state(order)
      return 'canceled' if order.canceled?
      return 'pending' unless order.can_ship?
      return 'pending' if inventory_units.any? &:backordered?
      return 'shipped' if state == 'shipped'
      order.paid? ? 'ready' : 'pending'
    end

    def tracking_url
      @tracking_url ||= shipping_method.build_tracking_url(tracking)
    end

    def include?(variant)
      inventory_units_for(variant).present?
    end

    def inventory_units_for(variant)
      inventory_units.where(variant_id: variant.id)
    end

    def inventory_units_for_item(line_item, variant = nil)
      inventory_units.where(line_item_id: line_item.id, variant_id: line_item.variant.id || variant.id)
    end

    def to_package
      package = Stock::Package.new(stock_location, order)
      grouped_inventory_units = inventory_units.includes(:line_item).group_by do |iu|
        [iu.line_item, iu.state_name]
      end

      grouped_inventory_units.each do |(line_item, state_name), inventory_units|
        package.add line_item, inventory_units.count, state_name
      end
      package
    end

    def set_up_inventory(state, variant, order, line_item)
      self.inventory_units.create(
        state: state,
        variant_id: variant.id,
        order_id: order.id,
        line_item_id: line_item.id
      )
    end

    def update_amounts
      if selected_shipping_rate
        self.update_columns(
          cost: selected_shipping_rate.cost,
          adjustment_total: adjustments.additional.map(&:update!).compact.sum,
          updated_at: Time.now,
        )
      end
    end

    private

      def manifest_unstock(item)
        stock_location.unstock item.variant, item.quantity, self
      end

      def manifest_restock(item)
        if item.states["on_hand"].to_i > 0
         stock_location.restock item.variant, item.states["on_hand"], self
        end

        if item.states["backordered"].to_i > 0
          stock_location.restock_backordered item.variant, item.states["backordered"]
        end
      end

      def description_for_shipping_charge
        "#{Spree.t(:shipping)} (#{shipping_method.name})"
      end

      def validate_shipping_method
        unless shipping_method.nil?
          errors.add :shipping_method, Spree.t(:is_not_available_to_shipment_address) unless shipping_method.include?(address)
        end
      end

      def after_ship
        inventory_units.each &:ship!
        send_shipped_email
        touch :shipped_at
        update_order_shipment_state
      end

      def update_order_shipment_state
        new_state = OrderUpdater.new(order).update_shipment_state
        order.update_columns(
          shipment_state: new_state,
          updated_at: Time.now,
        )
      end

      def send_shipped_email
        ShipmentMailer.shipped_email(self.id).deliver
      end

      def set_cost_zero_when_nil
        self.cost = 0 unless self.cost
      end


      def update_adjustments
        if cost_changed? && state != 'shipped'
          recalculate_adjustments
        end
      end

      def recalculate_adjustments
        Spree::ItemAdjustments.new(self).update
      end

      def can_get_rates?
        order.ship_address && order.ship_address.valid?
      end
  end
end
