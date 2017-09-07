namespace :exchanges do
  desc %q{Takes unreturned exchanged items and creates a new order to charge
  the customer for not returning them}
  task charge_unreturned_items: :environment do
    unreturned_return_items_scope = Spree::ReturnItem.awaiting_return.exchange_processed
    unreturned_return_items = unreturned_return_items_scope.joins(:exchange_inventory_units).where([
      'spree_inventory_units.created_at < :days_ago AND spree_inventory_units.state = :iu_state',
      days_ago: Spree::Config[:expedited_exchanges_days_window].days.ago, iu_state: 'shipped'
    ]).distinct.to_a

    # Determine that a return item has already been deemed unreturned and therefore charged
    # by the fact that its exchange inventory unit has popped off to a different order
    unreturned_return_items.select! { |ri| ri.exchange_inventory_units.exists?(order_id: ri.inventory_unit.order_id) }

    failed_orders = []

    unreturned_return_items.group_by(&:exchange_shipments).each do |shipments, return_items|
      begin
        original_order = shipments.first.order
        order_attributes = {
          bill_address: original_order.bill_address,
          ship_address: original_order.ship_address,
          email: original_order.email
        }
        order_attributes[:store_id] = original_order.store_id
        order = Spree::Order.create!(order_attributes)

        order.associate_user!(original_order.user) if original_order.user

        return_items.group_by(&:exchange_variant).map do |variant, variant_return_items|
          variant_inventory_units = variant_return_items.map(&:exchange_inventory_units).flatten
          line_item = Spree::LineItem.create!(variant: variant, quantity: variant_return_items.count, order: order)
          variant_inventory_units.each { |i| i.update_attributes!(line_item_id: line_item.id, order_id: order.id) }
        end

        order.reload.update_with_updater!
        while order.state != order.checkout_steps[-2] && order.next; end

        unless order.payments.present?
          card_to_reuse = original_order.valid_credit_cards.first
          card_to_reuse = original_order.user.credit_cards.default.first if !card_to_reuse && original_order.user
          Spree::Payment.create!(order: order,
                                 payment_method_id: card_to_reuse.try(:payment_method_id),
                                 source: card_to_reuse,
                                 amount: order.total)
        end

        # the order builds a shipment on its own on transition to delivery, but we want
        # the original exchange shipment, not the built one
        order.shipments.destroy_all
        shipments.each { |shipment| shipment.update_attributes!(order_id: order.id) }
        order.update_attributes!(state: 'confirm')

        order.reload.next!
        order.update_with_updater!
        order.finalize!

        failed_orders << order unless order.completed? && order.valid?
      rescue
        failed_orders << order
      end
    end
    failure_message = failed_orders.map { |o| "#{o.number} - #{o.errors.full_messages}" }.join(', ')
    raise UnableToChargeForUnreturnedItems, failure_message if failed_orders.present?
  end
end

class UnableToChargeForUnreturnedItems < StandardError; end
