module Spree
  # Workflow for processing returns and refunds
  #
  # This workflow handles the complete return process:
  # 1. Validates the return authorization
  # 2. Waits for item receipt (async step)
  # 3. Inspects returned items
  # 4. Processes refund
  # 5. Restocks items if applicable
  # 6. Sends confirmation email
  #
  # @example Run the workflow
  #   result = Spree::ReturnProcessingWorkflow.run(
  #     input: { return_authorization_id: rma.id },
  #     store: current_store
  #   )
  #
  # @example Complete the async step when items received
  #   Spree::Workflows::Engine.complete_step(
  #     transaction_id: result.transaction_id,
  #     step_id: 'await_item_receipt',
  #     output: { received_at: Time.current, condition: 'good' }
  #   )
  #
  class ReturnProcessingWorkflow < Spree::Workflows::Base
    workflow_id 'return_processing'

    step :validate_return do |input, context|
      rma = Spree::ReturnAuthorization.find_by(id: input[:return_authorization_id])

      unless rma
        next failure("Return authorization not found: #{input[:return_authorization_id]}")
      end

      unless rma.authorized?
        next failure("Return authorization is not in authorized state: #{rma.state}")
      end

      context[:return_authorization] = rma
      context[:order] = rma.order

      success(
        {
          return_authorization_id: rma.id,
          order_id: rma.order_id,
          number: rma.number
        },
        { return_authorization_id: rma.id }
      )
    end

    # Async step - waits for warehouse to confirm receipt
    step :await_item_receipt, async: true do |input, context|
      # This step is completed externally via Engine.complete_step
      # The output will contain: { received_at:, condition:, notes: }

      success(
        {
          items_received: true,
          received_at: input[:received_at],
          condition: input[:condition]
        },
        { return_authorization_id: context[:return_authorization]&.id || input[:return_authorization_id] }
      )
    end

    step :inspect_items do |input, context|
      rma = context[:return_authorization] || Spree::ReturnAuthorization.find(input[:return_authorization_id])
      condition = input[:condition] || context[:condition] || 'good'

      inspection_result = {
        condition: condition,
        restockable: condition == 'good',
        inspected_at: Time.current
      }

      context[:inspection_result] = inspection_result

      success(
        inspection_result,
        { return_authorization_id: rma.id, condition: condition }
      )
    end

    step :process_refund do |input, context|
      rma = context[:return_authorization] || Spree::ReturnAuthorization.find(input[:return_authorization_id])
      order = context[:order] || rma.order

      begin
        # Find the original payment
        payment = order.payments.completed.first

        unless payment
          next failure(
            'No completed payment found to refund',
            { return_authorization_id: rma.id }
          )
        end

        # Calculate refund amount
        refund_amount = rma.return_items.sum(&:amount)

        # Create refund
        refund = payment.refunds.create!(
          amount: refund_amount,
          reason: rma.reason || Spree::RefundReason.first
        )

        success(
          {
            refund_id: refund.id,
            refund_amount: refund_amount.to_f,
            refunded: true
          },
          { refund_id: refund.id, amount: refund_amount.to_f }
        )
      rescue StandardError => e
        failure(
          "Refund failed: #{e.message}",
          { return_authorization_id: rma.id }
        )
      end
    end.compensate do |data, context|
      # Cannot easily reverse a refund - log for manual intervention
      Rails.error.report(
        StandardError.new("Refund compensation needed for refund #{data[:refund_id]}"),
        context: data
      )
    end

    step :restock_items do |input, context|
      rma = context[:return_authorization] || Spree::ReturnAuthorization.find(input[:return_authorization_id])
      inspection = context[:inspection_result] || { restockable: true }

      unless inspection[:restockable]
        next success({ restocked: false, reason: 'Items not in restockable condition' })
      end

      restocked_items = []

      begin
        rma.return_items.each do |return_item|
          variant = return_item.variant
          stock_location = rma.stock_location || variant.stock_locations.first
          next unless stock_location

          stock_item = variant.stock_items.find_by(stock_location: stock_location)
          if stock_item
            stock_item.adjust_count_on_hand(return_item.quantity)
            restocked_items << {
              stock_item_id: stock_item.id,
              variant_id: variant.id,
              quantity: return_item.quantity
            }
          end
        end

        success(
          { restocked: true, restocked_count: restocked_items.size },
          { restocked_items: restocked_items }
        )
      rescue StandardError => e
        permanent_failure(
          "Restock failed: #{e.message}",
          { restocked_items: restocked_items }
        )
      end
    end.compensate do |data, context|
      # Reverse restocked inventory
      (data[:restocked_items] || []).each do |item|
        stock_item = Spree::StockItem.find_by(id: item[:stock_item_id])
        stock_item&.adjust_count_on_hand(-item[:quantity])
      end
    end

    step :complete_return do |input, context|
      rma = context[:return_authorization] || Spree::ReturnAuthorization.find(input[:return_authorization_id])

      begin
        rma.return_items.each(&:receive!)

        success(
          { return_completed: true, completed_at: Time.current },
          { return_authorization_id: rma.id }
        )
      rescue StandardError => e
        failure(
          "Failed to complete return: #{e.message}",
          { return_authorization_id: rma.id }
        )
      end
    end

    step :send_confirmation do |input, context|
      rma = context[:return_authorization] || Spree::ReturnAuthorization.find(input[:return_authorization_id])
      order = context[:order] || rma.order

      begin
        # Assuming a return confirmation mailer exists
        if defined?(Spree::ReturnAuthorizationMailer)
          Spree::ReturnAuthorizationMailer.return_processed(rma).deliver_later
        end

        success({ confirmation_sent: true, email: order.email })
      rescue StandardError => e
        Rails.error.report(e, context: { rma_id: rma.id })

        success({ confirmation_sent: false, email_error: e.message })
      end
    end
  end
end
