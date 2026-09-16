module Spree
  module AgentTools
    # The tools Spree ships: the generic read tools, and the workflows exposed
    # as write tools.
    #
    # The write allowlist is the whole catalog of back-office writes an agent
    # may make. Every entry names a `Spree::Dependencies` key, so a host app
    # that swaps in its own workflow class keeps the tool and gets the
    # replacement's schema; and a permission, which must equal the write scope
    # of the admin controller that invokes the same workflow — a contract spec
    # in `spree_api` fails when the two disagree, or when a controller gains a
    # workflow that is neither listed here nor excluded below.
    module DefaultCatalog
      # Read tools, and the writes that are not workflows.
      TOOLS = %w[
        Spree::AgentTools::SearchResources
        Spree::AgentTools::GetResource
        Spree::AgentTools::DescribeResource
        Spree::AgentTools::CreateResource
        Spree::AgentTools::UpdateResource
        Spree::AgentTools::DeleteResource
        Spree::AgentTools::QueryReport
        Spree::AgentTools::DescribeReporting
        Spree::AgentTools::CreateExport
        Spree::AgentTools::GetImportStatus
        Spree::AgentTools::DescribeImportMapping
        Spree::AgentTools::ProposeImportMapping
      ].freeze

      # Workflow key => permission, or => {permission:, except:, summary:}.
      WORKFLOWS = {
        # Catalog
        product_create_workflow: 'write_products',
        product_update_workflow: 'write_products',
        product_destroy_workflow: 'write_products',
        product_activate_workflow: 'write_products',
        product_draft_workflow: 'write_products',
        product_archive_workflow: 'write_products',
        product_approve_workflow: 'write_products',
        product_reject_workflow: 'write_products',
        variant_create_workflow: 'write_products',
        variant_update_workflow: 'write_products',
        catalog_create_workflow: 'write_products',
        catalog_update_workflow: 'write_products',
        catalog_activate_workflow: 'write_products',
        catalog_deactivate_workflow: 'write_products',
        price_list_create_workflow: 'write_products',
        price_list_update_workflow: 'write_products',
        price_list_activate_workflow: 'write_products',
        price_list_deactivate_workflow: 'write_products',

        # Orders. `restock_items` is hidden: it is deprecated and ignored, so
        # offering it would invite a model to set something that does nothing.
        order_cancel_workflow: { permission: 'write_orders', except: %i[restock_items] },

        # Fulfillment
        fulfillment_create_workflow: 'write_fulfillments',
        fulfillment_mark_delivered_workflow: 'write_fulfillments',
        delivery_update_tracking_workflow: 'write_orders',
        shipping_label_purchase_workflow: 'write_orders',
        shipping_label_refund_workflow: 'write_orders',

        # Money
        payment_capture_workflow: 'write_payments',
        payment_void_workflow: 'write_payments',
        refund_create_workflow: 'write_refunds',

        # Inventory
        stock_transfer_create_workflow: 'write_stock',
        stock_transfer_update_workflow: 'write_stock',
        stock_transfer_mark_ready_workflow: 'write_stock',
        stock_transfer_mark_in_transit_workflow: 'write_stock',
        stock_transfer_receive_workflow: 'write_stock',
        stock_transfer_cancel_workflow: 'write_stock',
        stock_transfer_mark_draft_workflow: 'write_stock',
        stock_transfer_close_workflow: 'write_stock',

        # Purchasing
        purchase_order_create_workflow: 'write_purchasing',
        purchase_order_update_workflow: 'write_purchasing',
        purchase_order_mark_ordered_workflow: 'write_purchasing',
        purchase_order_receive_workflow: 'write_purchasing',
        purchase_order_cancel_workflow: 'write_purchasing',
        purchase_order_mark_draft_workflow: 'write_purchasing',
        purchase_order_close_workflow: 'write_purchasing',

        # Marketplace
        seller_create_workflow: 'write_sellers',
        seller_invite_workflow: 'write_sellers',
        seller_approve_workflow: 'write_sellers',
        seller_reject_workflow: 'write_sellers',
        seller_suspend_workflow: 'write_sellers',
        seller_reopen_onboarding_workflow: 'write_sellers',
        seller_requirement_submission_accept_workflow: 'write_sellers',
        seller_requirement_submission_reject_workflow: 'write_sellers',
        seller_requirement_submission_waive_workflow: 'write_sellers',

        # B2B
        tax_exemption_certificate_verify_workflow: 'write_customers'
      }.freeze

      # Workflows an admin controller invokes that are deliberately NOT tools,
      # each with the reason. The contract spec reads this list, so a workflow
      # can never be quietly dropped: it is exposed, or it is here.
      EXCLUDED_WORKFLOWS = {
        customer_anonymize_workflow:
          'Irreversible erasure of a person\'s data under GDPR Art. 17. A deletion no one can undo ' \
          'is not something to offer a model behind one confirmation prompt.',
        invitation_accept_workflow:
          'Platform plumbing, not a merchant operation: it runs for the invited person from a ' \
          'tokenised link, and the controller skips the scope check entirely.',
        seller_payout_sweep_workflow:
          'Moves money to every eligible seller at once. A scheduled platform job, not a ' \
          'conversational action.',
        seller_payout_complete_workflow:
          'Settles a payout against the payment provider. Belongs to the payouts pipeline, which ' \
          'reconciles against provider state the agent cannot see.',
        import_start_mapping_workflow:
          'Step of the CSV import wizard, driven by a file upload. MCP carries no files.',
        import_complete_mapping_workflow:
          'Step of the CSV import wizard; the mapping proposal that feeds it stays in the ' \
          'dashboard assistant, which has the model.',
        import_retry_failed_rows_workflow:
          'Step of the CSV import wizard, meaningful only against a run the agent did not start.'
      }.freeze

      class << self
        # @param registry [Spree::AgentTools::Registry]
        # @return [void]
        def install(registry)
          TOOLS.each { |tool| registry << tool }
          registry.expose_workflows(**WORKFLOWS)
        end
      end
    end
  end
end
