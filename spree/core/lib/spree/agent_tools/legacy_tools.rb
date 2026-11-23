module Spree
  module AgentTools
    # The workflow tools Spree 6.0.0 offered, by the name and parameters a
    # client saw then, and the operation each now runs.
    #
    # 6.0.0 derived a tool from a workflow's `perform` signature, so its
    # parameters were the workflow's keywords (`order`, `reason`); a tool now
    # takes the operation's own (`id`, `cancel_reason_id`). This table, written
    # once from the 6.0.0 schemas, keeps those calls working through 6.0.x. It
    # is an explicit list, not a rule: nothing here guesses one name from
    # another.
    #
    # A parameter mapped to nil never reached the endpoint in 6.0.0 either; it
    # is ignored, and the result says so. One mapped to `:merge` was a hash of
    # fields, merged into the body, which is what 6.0.0 did with it.
    #
    # `deliveries_update_tracking` is not here: 6.0.0 sent it to the
    # mark-delivered endpoint and dropped its tracking fields, so a call meant
    # to record tracking marked the delivery delivered. No endpoint sets a
    # carrier status, so the name no longer answers rather than doing that.
    #
    # Removed in 6.3, with the names that are no longer listed.
    # See docs/plans/6.0-agent-tools-from-openapi.md.
    module LegacyTools
      # Old tool name => the operation it runs and its renamed parameters.
      TOOLS = {
        'catalogs_activate' => {
          verb: 'patch', path: '/api/v3/admin/catalogs/{id}/activate',
          parameters: { 'catalog' => 'id' }
        },
        'catalogs_deactivate' => {
          verb: 'patch', path: '/api/v3/admin/catalogs/{id}/deactivate',
          parameters: { 'catalog' => 'id' }
        },
        'fulfillments_create' => {
          verb: 'post', path: '/api/v3/admin/orders/{order_id}/fulfillments',
          parameters: {
            'order' => 'order_id', 'stock_location' => 'stock_location_id',
            'source_fulfillment' => 'source_fulfillment_id', 'delivery_method' => 'delivery_method_id'
          }
        },
        'fulfillments_mark_delivered' => {
          verb: 'patch', path: '/api/v3/admin/orders/{order_id}/fulfillments/{id}/mark_delivered',
          parameters: { 'fulfillment' => 'id' }
        },
        'orders_cancel' => {
          verb: 'patch', path: '/api/v3/admin/orders/{id}/cancel',
          parameters: { 'order' => 'id', 'canceled_at' => nil, 'reason' => 'cancel_reason_id', 'note' => 'cancel_note' }
        },
        'orders_complete' => {
          verb: 'patch', path: '/api/v3/admin/orders/{id}/complete',
          parameters: { 'order' => 'id' }
        },
        'payments_capture' => {
          verb: 'patch', path: '/api/v3/admin/orders/{order_id}/payments/{id}/capture',
          parameters: { 'payment' => 'id' }
        },
        'payments_void' => {
          verb: 'patch', path: '/api/v3/admin/orders/{order_id}/payments/{id}/void',
          parameters: { 'payment' => 'id' }
        },
        'price_lists_activate' => {
          verb: 'patch', path: '/api/v3/admin/price_lists/{id}/activate',
          parameters: { 'price_list' => 'id' }
        },
        'price_lists_deactivate' => {
          verb: 'patch', path: '/api/v3/admin/price_lists/{id}/deactivate',
          parameters: { 'price_list' => 'id' }
        },
        'products_activate' => {
          verb: 'patch', path: '/api/v3/admin/products/{id}/activate',
          parameters: { 'product' => 'id' }
        },
        'products_approve' => {
          verb: 'patch', path: '/api/v3/admin/products/{id}/approve',
          parameters: { 'product' => 'id' }
        },
        'products_archive' => {
          verb: 'patch', path: '/api/v3/admin/products/{id}/archive',
          parameters: { 'product' => 'id' }
        },
        'products_draft' => {
          verb: 'patch', path: '/api/v3/admin/products/{id}/draft',
          parameters: { 'product' => 'id' }
        },
        'products_reject' => {
          verb: 'patch', path: '/api/v3/admin/products/{id}/reject',
          parameters: { 'product' => 'id' }
        },
        'purchase_orders_cancel' => {
          verb: 'patch', path: '/api/v3/admin/purchase_orders/{id}/cancel',
          parameters: { 'purchase_order' => 'id' }
        },
        'purchase_orders_close' => {
          verb: 'patch', path: '/api/v3/admin/purchase_orders/{id}/close',
          parameters: { 'purchase_order' => 'id' }
        },
        'purchase_orders_mark_draft' => {
          verb: 'patch', path: '/api/v3/admin/purchase_orders/{id}/mark_draft',
          parameters: { 'purchase_order' => 'id' }
        },
        'purchase_orders_mark_ordered' => {
          verb: 'patch', path: '/api/v3/admin/purchase_orders/{id}/mark_ordered',
          parameters: { 'purchase_order' => 'id' }
        },
        'purchase_orders_receive' => {
          verb: 'post', path: '/api/v3/admin/purchase_orders/{purchase_order_id}/stock_receipts',
          parameters: { 'purchase_order' => 'purchase_order_id' }
        },
        'refunds_create' => {
          verb: 'post', path: '/api/v3/admin/orders/{order_id}/refunds',
          parameters: {
            'payment' => 'payment_id', 'reason' => 'refund_reason_id', 'originator' => nil,
            'order' => 'order_id', 'tax_amount' => nil
          }
        },
        'seller_requirement_submissions_accept' => {
          verb: 'patch', path: '/api/v3/admin/sellers/{seller_id}/requirement_submissions/{id}/accept',
          parameters: { 'submission' => 'id' }
        },
        'seller_requirement_submissions_reject' => {
          verb: 'patch', path: '/api/v3/admin/sellers/{seller_id}/requirement_submissions/{id}/reject',
          parameters: { 'submission' => 'id' }
        },
        'seller_requirement_submissions_waive' => {
          verb: 'post', path: '/api/v3/admin/sellers/{seller_id}/requirement_submissions',
          parameters: { 'seller' => 'seller_id', 'requirement' => 'requirement_id' }
        },
        'sellers_approve' => {
          verb: 'patch', path: '/api/v3/admin/sellers/{id}/approve',
          parameters: { 'seller' => 'id' }
        },
        'sellers_invite' => {
          verb: 'post', path: '/api/v3/admin/sellers/{id}/invite',
          parameters: { 'seller' => 'id', 'inviter' => nil, 'role' => 'role_id' }
        },
        'sellers_reject' => {
          verb: 'patch', path: '/api/v3/admin/sellers/{id}/reject',
          parameters: { 'seller' => 'id' }
        },
        'sellers_reopen_onboarding' => {
          verb: 'patch', path: '/api/v3/admin/sellers/{id}/reopen_onboarding',
          parameters: { 'seller' => 'id' }
        },
        'sellers_suspend' => {
          verb: 'patch', path: '/api/v3/admin/sellers/{id}/suspend',
          parameters: { 'seller' => 'id' }
        },
        'shipping_labels_purchase' => {
          verb: 'post', path: '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/labels',
          parameters: { 'owner' => 'fulfillment_id' }
        },
        'shipping_labels_refund' => {
          verb: 'patch', path: '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/labels/{id}/refund',
          parameters: { 'shipping_label' => 'id' }
        },
        'stock_transfers_cancel' => {
          verb: 'patch', path: '/api/v3/admin/stock_transfers/{id}/cancel',
          parameters: { 'stock_transfer' => 'id' }
        },
        'stock_transfers_close' => {
          verb: 'patch', path: '/api/v3/admin/stock_transfers/{id}/close',
          parameters: { 'stock_transfer' => 'id' }
        },
        'stock_transfers_mark_draft' => {
          verb: 'patch', path: '/api/v3/admin/stock_transfers/{id}/mark_draft',
          parameters: { 'stock_transfer' => 'id' }
        },
        'stock_transfers_mark_in_transit' => {
          verb: 'patch', path: '/api/v3/admin/stock_transfers/{id}/mark_in_transit',
          parameters: { 'stock_transfer' => 'id' }
        },
        'stock_transfers_mark_ready' => {
          verb: 'patch', path: '/api/v3/admin/stock_transfers/{id}/mark_ready',
          parameters: { 'stock_transfer' => 'id' }
        },
        'stock_transfers_receive' => {
          verb: 'post', path: '/api/v3/admin/stock_transfers/{stock_transfer_id}/stock_receipts',
          parameters: { 'stock_transfer' => 'stock_transfer_id' }
        },
        'tax_exemption_certificates_verify' => {
          verb: 'patch', path: '/api/v3/admin/companies/{company_id}/tax_exemption_certificates/{id}/verify',
          parameters: { 'certificate' => 'id' }
        },
        'variants_create' => {
          verb: 'post', path: '/api/v3/admin/products/{product_id}/variants',
          parameters: { 'product' => 'product_id', 'attributes' => :merge }
        },
        'variants_update' => {
          verb: 'patch', path: '/api/v3/admin/products/{product_id}/variants/{id}',
          parameters: { 'variant' => 'id', 'attributes' => :merge }
        }
      }.freeze

      class << self
        # The 6.0.0 parameters of a tool that keeps its name, when it still
        # runs the same operation.
        #
        # @param name [String]
        # @param verb [String]
        # @param path [String] the OpenAPI path
        # @return [Hash{String => String, Symbol, nil}]
        def parameters_for(name, verb, path)
          tool = TOOLS[name.to_s]
          return {} unless tool && tool[:verb] == verb.to_s && tool[:path] == path

          tool[:parameters]
        end
      end
    end
  end
end
