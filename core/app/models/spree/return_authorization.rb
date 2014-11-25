module Spree
  class ReturnAuthorization < Spree::Base
    include Spree::Core::Permalinks.new(prefix: 'RMA', length: 9)

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :return_authorizations

    has_many :inventory_units, dependent: :nullify, inverse_of: :return_authorization
    belongs_to :stock_location
    before_save :force_positive_amount

    validates :order, presence: true
    validates :amount, numericality: true
    validate :must_have_shipped_units

    state_machine initial: :authorized do
      after_transition to: :received, do: :process_return

      event :receive do
        transition to: :received, from: :authorized, if: :allow_receive?
      end
      event :cancel do
        transition to: :canceled, from: :authorized
      end
    end

    def currency
      order.nil? ? Spree::Config[:currency] : order.currency
    end

    def display_amount
      Spree::Money.new(amount, { currency: currency })
    end

    def add_variant(variant_id, quantity)
      order_units = returnable_inventory.group_by(&:variant_id)
      returned_units = inventory_units.group_by(&:variant_id)
      return false if order_units.empty?

      count = 0

      if returned_units[variant_id].nil? || returned_units[variant_id].size < quantity
        count = returned_units[variant_id].nil? ? 0 : returned_units[variant_id].size

        order_units[variant_id].each do |inventory_unit|
          next unless inventory_unit.return_authorization.nil? && count < quantity

          inventory_unit.return_authorization = self
          inventory_unit.save!

          count += 1
        end
      elsif returned_units[variant_id].size > quantity
        (returned_units[variant_id].size - quantity).times do |i|
          returned_units[variant_id][i].return_authorization_id = nil
          returned_units[variant_id][i].save!
        end
      end

      order.authorize_return! if inventory_units.reload.size > 0 && !order.awaiting_return?
    end

    def returnable_inventory
      order.shipped_shipments.collect{|s| s.inventory_units.to_a}.flatten
    end

    # Used when Adjustment#update! wants to update the related adjustment
    def compute_amount(*args)
      amount.abs * -1
    end

    private

      def must_have_shipped_units
        errors.add(:order, Spree.t(:has_no_shipped_units)) if order.nil? || !order.shipped_shipments.any?
      end

      def process_return
        inventory_units(include: :variant).each do |iu|
          iu.return!

          if iu.variant.should_track_inventory?
            if stock_item = Spree::StockItem.find_by(variant_id: iu.variant_id, stock_location_id: stock_location_id)
              Spree::StockMovement.create!(stock_item_id: stock_item.id, quantity: 1)
            end
          end
        end

        order.create_adjustment!(
          adjustable: order,
          amount:     compute_amount,
          label:      Spree.t(:rma_credit),
          source:     self
        )

        order.update!

        order.return if inventory_units.all?(&:returned?)
      end

      def allow_receive?
        !inventory_units.empty?
      end

      def force_positive_amount
        self.amount = amount.abs
      end
  end
end
