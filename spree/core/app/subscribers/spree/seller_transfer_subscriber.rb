# frozen_string_literal: true

module Spree
  # Credits a seller once their order's goods have all gone out.
  #
  # Subscribes to `order.fulfilled` only, never the legacy `order.shipped` it
  # is dual-emitted alongside — both would fire this. The workflow is
  # idempotent regardless, but crediting twice and relying on a unique index to
  # refuse it is not a design, it is a rescue.
  #
  # Asynchronous, unlike the commission subscriber: a provider that moves money
  # makes a network call, and a fulfillment must not wait on a bank. What the
  # seller earned is already determined by the time this runs — the order is
  # fulfilled and its commission is written — so nothing is lost by deferring.
  class SellerTransferSubscriber < Spree::Subscriber
    subscribes_to 'order.fulfilled'

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order
      return if order.seller_id.blank?

      Spree.seller_transfer_create_workflow.call(order: order)
    end
  end
end
