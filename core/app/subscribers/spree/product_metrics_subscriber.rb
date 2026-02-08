# frozen_string_literal: true

module Spree
  # Handles order completion events to update product metrics.
  #
  # When an order is completed, this subscriber enqueues background jobs
  # to refresh the metrics (units_sold_count, revenue) for each product
  # in the order.
  class ProductMetricsSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    on 'order.completed', :refresh_product_metrics

    def refresh_product_metrics(event)
      order_id = event.payload['id']
      return unless order_id

      order = Spree::Order.find_by_param(order_id)
      return unless order
      return unless order.store_id

      product_ids = order.line_items.includes(:variant).map { |li| li.variant.product_id }.uniq
      return if product_ids.empty?

      jobs = product_ids.map { |product_id| Spree::Products::RefreshMetricsJob.new(product_id, order.store_id) }
      ActiveJob.perform_all_later(jobs)
    end
  end
end
