module Spree
  class FulfilmentChanger
    include ActiveModel::Validations

    validates :quantity, numericality: { greater_than: 0 }
    validates :desired_stock_location, presence: true
    validate  :current_shipment_not_already_shipped
    validate  :desired_shipment_different_from_current
    validate  :enough_stock_at_desired_location, if: :handle_stock_counts?

    def initialize(params = {})
      # TODO: check if stocks' count_on_hand is correct after split (admin/products/checked-shirt/stock)
      # TODO: Is there a case when shipment has more than one on_hand inventory unit?
      @current_stock_location = params[:current_stock_location]
      @desired_stock_location = params[:desired_stock_location]
      @current_shipment       = params[:current_shipment]
      @desired_shipment       = params[:desired_shipment]
      @variant                = params[:variant]
      @quantity               = params[:quantity]
      @available_quantity     = [
        desired_stock_location.try(:count_on_hand, variant).to_i,
        current_quantity
      ].max
    end

    def run!
      return false if invalid?

      desired_shipment.save! if desired_shipment.new_record?

      handle_stock
      reload_shipment_inventory_units
      after_process_shipments

      true
    end

    private

    attr_reader :variant, :quantity, :current_stock_location, :desired_stock_location,
                :current_shipment, :desired_shipment, :available_quantity

    def handle_stock
      ActiveRecord::Base.transaction do
        if handle_stock_counts?
          current_stock_location.restock(variant, current_on_hand_quantity, current_shipment)
          desired_stock_location.unstock(variant, unstock_quantity, desired_shipment)
        end

        move_inventory_units_between_shipments
      end
    end

    def move_inventory_units_between_shipments
      update_desired_shipment_inventory_units
      update_current_shipment_inventory_units
    end

    def current_shipment_units
      current_shipment.inventory_units.where(variant_id: variant.id)
    end

    def update_desired_shipment_inventory_units
      on_hand_unit = get_desired_shipment_inventory_unit(:on_hand)
      on_hand_unit.update(quantity: on_hand_unit.quantity + new_on_hand_quantity)

      if new_backorder_quantity.present?
        backordered_unit = get_desired_shipment_inventory_unit(:backordered)
        backordered_unit.update(quantity: backordered_unit.quantity + new_backorder_quantity)
      end
    end

    def update_current_shipment_inventory_units
      on_hand_quantity = quantity
      backordered_units = current_shipment_units.find_by(state: :backordered)

      if backordered_units.present? && backordered_units.quantity > 0
        backordered_units.update(quantity: 0)
        on_hand_quantity -= backordered_units.quantity
      end
      current_shipment_units.find_by(state: :on_hand).decrement!(:quantity, on_hand_quantity) if on_hand_quantity > 0
    end

    def get_desired_shipment_inventory_unit(state)
      desired_shipment.inventory_units.find_or_create_by(state: state) do |unit|
        current_shipment_unit = current_shipment.inventory_units.first
        unit.variant_id = current_shipment_unit.variant_id
        unit.order_id = current_shipment_unit.order_id
        unit.line_item_id = current_shipment_unit.line_item_id
        unit.quantity = 0
      end
    end

    def after_process_shipments
      if current_shipment.inventory_units.sum(:quantity).zero?
        current_shipment.destroy!
      else
        current_shipment.refresh_rates
      end

      desired_shipment.refresh_rates

      desired_shipment.order.reload
      desired_shipment.order.update_with_updater!
    end

    def new_on_hand_quantity
      [available_quantity, quantity].min
    end

    def new_backorder_quantity
      quantity - new_on_hand_quantity
    end

    def unstock_quantity
      desired_stock_location.backorderable?(variant) ? quantity : new_on_hand_quantity
    end

    def current_on_hand_quantity
      [current_shipment.inventory_units.on_hand_or_backordered.size, quantity].min
    end

    def reload_shipment_inventory_units
      [current_shipment, desired_shipment].each { |shipment| shipment.inventory_units.reload }
    end

    def current_quantity
      desired_stock_location == current_stock_location ? quantity : 0
    end

    def handle_stock_counts?
      current_shipment.order.completed? && current_stock_location != desired_stock_location
    end

    def current_shipment_not_already_shipped
      return unless current_shipment.shipped?

      errors.add(:current_shipment, :has_already_been_shipped)
    end

    def enough_stock_at_desired_location
      return if Spree::Stock::Quantifier.new(variant, desired_stock_location).can_supply?(quantity)

      errors.add(:desired_shipment, :has_not_enough_stock_at_desired_location)
    end

    def desired_shipment_different_from_current
      return unless desired_shipment.id == current_shipment.id

      errors.add(:desired_shipment, :can_not_transfer_within_same_shipment)
    end
  end
end
