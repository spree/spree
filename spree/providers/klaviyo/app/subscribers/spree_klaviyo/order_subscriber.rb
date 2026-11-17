module SpreeKlaviyo
  # Sends a purchase to Klaviyo once: from the order, or from the order group
  # for a split checkout, whose child orders send nothing.
  class OrderSubscriber < Spree::Subscriber
    subscribes_to 'order.placed', 'order_group.completed', 'order.canceled'

    on 'order.placed', :order_placed
    on 'order_group.completed', :order_group_completed
    on 'order.canceled', :order_canceled

    private

    def order_placed(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return if order.nil? || order.grouped?

      track_purchase(order, event)
    end

    def order_group_completed(event)
      group = Spree::OrderGroup.find_by_prefix_id(event.payload['id'])
      return unless group

      track_purchase(group, event)
    end

    def order_canceled(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      integration = order && Spree::Integrations::Klaviyo.active_for(order.store)
      return unless integration

      SpreeKlaviyo::TrackEventJob.perform_later(integration, order, 'canceled_order', notify_customer: notify_customer?(event))
    end

    # A group's profile comes from its cart.
    def track_purchase(purchase, event)
      integration = Spree::Integrations::Klaviyo.active_for(purchase.store)
      return unless integration

      profile_source = purchase.is_a?(Spree::OrderGroup) ? purchase.cart || purchase : purchase
      ActiveJob.perform_all_later(
        SpreeKlaviyo::SyncProfileJob.new(integration, profile_source),
        SpreeKlaviyo::TrackEventJob.new(integration, purchase, 'placed_order', notify_customer: notify_customer?(event)),
        *purchase.line_items.map { |line_item| SpreeKlaviyo::TrackEventJob.new(integration, line_item, 'ordered_product') }
      )
    end

    # Staff can place or cancel an order without telling the customer; absent
    # metadata means they were told.
    def notify_customer?(event)
      event.metadata.fetch('notify_customer', true) != false
    end
  end
end
