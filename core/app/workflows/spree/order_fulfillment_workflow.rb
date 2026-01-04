module Spree
  # Workflow for processing order fulfillment
  #
  # This workflow handles the complete order fulfillment process:
  # 1. Validates the order can be fulfilled
  # 2. Reserves inventory for all line items
  # 3. Authorizes payment
  # 4. Creates shipments
  # 5. Captures payment
  # 6. Sends confirmation email
  #
  # Each step has compensation logic to rollback on failure.
  #
  # @example Run the workflow
  #   result = Spree::OrderFulfillmentWorkflow.run(
  #     input: { order_id: order.id },
  #     store: current_store
  #   )
  #
  # @example Check result
  #   if result.success?
  #     puts "Order fulfilled: #{result.output}"
  #   else
  #     puts "Failed: #{result.error}"
  #   end
  #
  # @example Extending the workflow with hooks (in an extension or initializer)
  #   # Add a fraud check after order validation
  #   Spree::OrderFulfillmentWorkflow.hooks.after_order_validated do |context|
  #     FraudService.check(context[:order])
  #   end.compensate do |context|
  #     FraudService.release_hold(context[:order])
  #   end
  #
  #   # Add loyalty points after payment capture
  #   Spree::OrderFulfillmentWorkflow.hooks.after_payment_captured do |context|
  #     LoyaltyService.award_points(context[:order])
  #   end
  #
  class OrderFulfillmentWorkflow < Spree::Workflows::Base
    workflow_id 'order_fulfillment'

    step :validate_order do |input, context|
      order = Spree::Order.find_by(id: input[:order_id])

      unless order
        next failure("Order not found: #{input[:order_id]}")
      end

      unless order.can_complete?
        next failure("Order cannot be fulfilled: #{order.errors.full_messages.join(', ')}")
      end

      context[:order] = order
      success(
        { order_id: order.id, order_number: order.number },
        { order_id: order.id }
      )
    end

    # Hook: Extensions can add fraud checks, custom validations, etc.
    define_hook :after_order_validated

    step :validate_inventory do |input, context|
      order = context[:order] || Spree::Order.find(input[:order_id])
      insufficient_items = []

      order.line_items.each do |line_item|
        unless line_item.variant.can_supply?(line_item.quantity)
          insufficient_items << {
            variant_id: line_item.variant_id,
            sku: line_item.variant.sku,
            requested: line_item.quantity,
            available: line_item.variant.total_on_hand
          }
        end
      end

      if insufficient_items.any?
        next failure(
          "Insufficient inventory for items: #{insufficient_items.map { |i| i[:sku] }.join(', ')}",
          { order_id: order.id, insufficient_items: insufficient_items }
        )
      end

      success(
        { inventory_validated: true },
        { order_id: order.id }
      )
    end

    step :reserve_inventory do |input, context|
      order = context[:order] || Spree::Order.find(input[:order_id])
      reserved_items = []

      begin
        order.line_items.each do |line_item|
          stock_item = line_item.variant.stock_items.first
          next unless stock_item

          stock_item.adjust_count_on_hand(-line_item.quantity)
          reserved_items << {
            stock_item_id: stock_item.id,
            variant_id: line_item.variant_id,
            quantity: line_item.quantity
          }
        end

        success(
          { inventory_reserved: true, reserved_count: reserved_items.size },
          { reserved_items: reserved_items }
        )
      rescue StandardError => e
        # Partial failure - pass what was reserved for compensation
        permanent_failure(
          "Failed to reserve inventory: #{e.message}",
          { reserved_items: reserved_items }
        )
      end
    end.compensate do |data, context|
      # Restore reserved inventory
      (data[:reserved_items] || []).each do |item|
        stock_item = Spree::StockItem.find_by(id: item[:stock_item_id])
        stock_item&.adjust_count_on_hand(item[:quantity])
      end
    end

    # Hook: Extensions can add warehouse notifications, allocation logic, etc.
    define_hook :after_inventory_reserved

    step :authorize_payment do |input, context|
      order = context[:order] || Spree::Order.find(input[:order_id])
      payment = order.payments.pending.first

      unless payment
        next failure('No pending payment found', { order_id: order.id })
      end

      begin
        payment.authorize!

        success(
          { payment_id: payment.id, payment_authorized: true },
          { payment_id: payment.id }
        )
      rescue Spree::Core::GatewayError => e
        failure(
          "Payment authorization failed: #{e.message}",
          { payment_id: payment.id }
        )
      end
    end.compensate do |data, context|
      # Void the authorization
      payment = Spree::Payment.find_by(id: data[:payment_id])
      payment&.void_transaction! if payment&.pending?
    end

    step :create_shipments do |input, context|
      order = context[:order] || Spree::Order.find(input[:order_id])

      begin
        order.create_proposed_shipments
        shipment_ids = order.shipments.pluck(:id)

        success(
          { shipments_created: true, shipment_count: shipment_ids.size },
          { shipment_ids: shipment_ids }
        )
      rescue StandardError => e
        failure(
          "Failed to create shipments: #{e.message}",
          { order_id: order.id }
        )
      end
    end.compensate do |data, context|
      # Cancel created shipments
      Spree::Shipment.where(id: data[:shipment_ids]).find_each do |shipment|
        shipment.cancel! if shipment.can_cancel?
      end
    end

    step :capture_payment do |input, context|
      payment = Spree::Payment.find_by(id: context[:payment_id] || input[:payment_id])

      unless payment
        next failure('Payment not found')
      end

      begin
        payment.capture!

        success(
          { payment_captured: true, amount: payment.amount.to_f },
          { payment_id: payment.id, captured_amount: payment.amount.to_f }
        )
      rescue Spree::Core::GatewayError => e
        failure(
          "Payment capture failed: #{e.message}",
          { payment_id: payment.id }
        )
      end
    end.compensate do |data, context|
      # Refund captured payment
      payment = Spree::Payment.find_by(id: data[:payment_id])
      if payment&.completed?
        payment.refunds.create!(
          amount: data[:captured_amount],
          reason: Spree::RefundReason.first || Spree::RefundReason.create!(name: 'Workflow Rollback')
        )
      end
    end

    # Hook: Extensions can add loyalty points, accounting entries, etc.
    define_hook :after_payment_captured

    step :complete_order do |input, context|
      order = context[:order] || Spree::Order.find(input[:order_id])

      begin
        order.complete!

        success(
          { order_completed: true, completed_at: order.completed_at },
          { order_id: order.id }
        )
      rescue StandardError => e
        failure(
          "Failed to complete order: #{e.message}",
          { order_id: order.id }
        )
      end
    end.compensate do |data, context|
      # Revert order status if possible
      order = Spree::Order.find_by(id: data[:order_id])
      order&.update_column(:state, 'payment') if order&.complete?
    end

    step :send_confirmation do |input, context|
      order = context[:order] || Spree::Order.find(input[:order_id])

      begin
        Spree::OrderMailer.confirm_email(order).deliver_later

        success({ confirmation_sent: true, email: order.email })
      rescue StandardError => e
        # Email failure shouldn't fail the whole workflow
        # Log but return success
        Rails.error.report(e, context: { order_id: order.id })

        success({ confirmation_sent: false, email_error: e.message })
      end
    end
    # No compensation needed for email - already sent is acceptable
  end
end
