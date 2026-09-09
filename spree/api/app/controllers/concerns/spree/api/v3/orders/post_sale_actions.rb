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

          # A payload whose `items` is not a list. Raised out of the params
          # helper so it cannot be mistaken for a workflow rejection, and
          # answered as the client mistake it is rather than a 500.
          class InvalidItems < StandardError; end

          included do
            rescue_from InvalidItems, with: :render_invalid_items
          end

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

          def render_invalid_items
            errors = ActiveModel::Errors.new(@resource || model_class.new)
            errors.add(:items, :invalid)
            render_validation_error(errors)
          end

          # The units a receive request named, or nil when it named none.
          #
          # An omitted `items` means "receive it all as requested". Naming an
          # empty list — or an explicit `null`, which is the same statement —
          # means the caller named no units, and must not fall through to
          # receive-all. Anything else that is not a list is refused rather
          # than iterated, which would answer a 500 to a client mistake.
          #
          # @param keys [Array<Symbol>] the per-item keys to permit
          # @return [Array<ActionController::Parameters>, nil]
          def received_items(keys)
            return nil unless params.key?(:items)

            sent = params.permit(items: keys)[:items]
            return [] if sent.nil?

            raise InvalidItems unless sent.respond_to?(:map) && !sent.is_a?(Hash)

            sent
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
