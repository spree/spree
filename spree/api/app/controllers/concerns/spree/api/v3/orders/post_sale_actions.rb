module Spree
  module Api
    module V3
      module Orders
        # What every post-sale record on an order has in common: it is opened
        # against the order, and then moved through its statuses one named
        # action at a time.
        #
        # Shared by the operator's branch and the seller's, which run the same
        # workflows with the same arguments. What differs between them is only
        # *whose records a payload may name*, and that stays in the including
        # controller: this concern never fetches an order, a variant or a
        # stock location, so including it cannot widen what a caller reaches.
        # `@order` and `@resource` arrive already fetched and authorized —
        # through `current_store` on one branch, `current_seller_orders` on
        # the other — and this code never learns which.
        module PostSaleActions
          extend ActiveSupport::Concern

          protected

          # Runs one of the record's status workflows and renders the result.
          #
          # The keyword the workflow expects for the record itself differs per
          # entity (+return_record:+, +exchange:+, +claim:+), so each concern
          # names its own.
          def run_workflow(workflow, **arguments)
            result = workflow.call(workflow_record_key => @resource, **arguments)

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_result_error(result)
            end
          end

          # @return [Symbol] the keyword this entity's workflows take it under
          def workflow_record_key
            raise NotImplementedError, "#{self.class} must implement #workflow_record_key"
          end

          # Opens the record against the order, through the entity's create
          # workflow.
          def create_post_sale_record(workflow, subject, **arguments)
            authorize!(:create, subject)

            result = workflow.call(
              order: @order,
              items: items_for_create,
              reason: reason_for_create,
              memo: create_params[:memo],
              created_by: try_spree_current_user,
              **arguments
            )

            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_result_error(result)
            end
          end
        end
      end
    end
  end
end
