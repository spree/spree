module Spree
  module Api
    module V3
      module Admin
        # What a stock transfer and a purchase order have in common as
        # endpoints: line items resolved out of a flat payload, and statuses
        # moved one named action at a time
        # (docs/plans/6.0-inventory-operations.md).
        #
        # Every id a payload names is resolved through the store — or through
        # the document itself, for its own lines — so an id belonging to
        # another tenant answers 404 rather than being acted on. That is also
        # why nothing here assigns a `*_id` from the payload: `permitted_params`
        # decodes prefixed ids into primary keys, and a decoded key carries no
        # evidence of whose record it is.
        module ReceivableActions
          extend ActiveSupport::Concern

          # A payload whose `items` is not a list. Raised out of the params
          # helper so it cannot be mistaken for a workflow rejection, and
          # answered as the client mistake it is rather than a 500.
          class InvalidItems < StandardError; end

          included do
            rescue_from InvalidItems, with: :render_invalid_items
          end

          protected

          # Runs one of the document's status workflows and renders the result.
          def run_transition(workflow, **arguments)
            result = workflow.call(workflow_record_key => @resource, **arguments)

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_result_error(result)
            end
          end

          # @return [Symbol] the keyword this document's workflows take it under
          def workflow_record_key
            raise NotImplementedError, "#{self.class} must implement #workflow_record_key"
          end

          # The lines a create or update named, or nil when the payload said
          # nothing about them — which on an update means "leave them alone".
          #
          # @param attribute_keys [Array<Symbol>] the per-line attributes this
          #   document accepts beyond the variant (`:quantity_shipped`,
          #   `:quantity_ordered`, `:unit_cost`)
          # @return [Array<Hash>, nil]
          def items_from_params(*attribute_keys)
            sent = sent_items([:variant_id, *attribute_keys])
            return nil if sent.nil?

            sent.map do |item|
              attributes = { variant: variants_scope.find_by_prefix_id!(item[:variant_id]) }
              attribute_keys.each { |key| attributes[key] = item[key] if item.key?(key.to_s) }
              attributes
            end
          end

          # What the warehouse counted, resolved through the document itself,
          # so a line from another transfer or order cannot be received here.
          #
          # An omitted `items` means "receive it all as expected". Naming an
          # empty list — or an explicit `null`, the same statement — means the
          # caller named no lines, and must not fall through to receive-all.
          #
          # @param keys [Array<Symbol>] the per-line keys to permit
          # @return [Array<Hash>, nil]
          def items_for_receive(keys)
            sent = sent_items(keys)
            return nil if sent.nil?

            sent.map do |item|
              {
                item: @resource.items.find_by_prefix_id!(item[:id]),
                quantity_received: item[:quantity_received],
                discrepancy_reason: item[:discrepancy_reason]
              }
            end
          end

          # Any of the store's warehouses the caller may see, or nil when the
          # payload did not name one.
          #
          # @return [Spree::StockLocation, nil]
          def stock_location_from(key)
            id = params[key]
            return nil if id.blank?

            current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id)
          end

          def variants_scope
            current_store.variants.accessible_by(current_ability, :show)
          end

          def render_invalid_items
            errors = ActiveModel::Errors.new(@resource || model_class.new)
            errors.add(:items, :invalid)
            render_validation_error(errors)
          end

          private

          # Raw `params`, not `permitted_params`: the latter decodes anything
          # shaped like a prefixed id into a primary key, and these lines are
          # looked up by prefixed id precisely so their scope is checked.
          #
          # The list-ness is checked before `permit`, which silently drops a
          # scalar `items` — leaving a client typo indistinguishable from "no
          # lines named", and answering 201 to a payload nobody meant.
          def sent_items(keys)
            return nil unless params.key?(:items)

            raw = params[:items]
            return [] if raw.nil?
            raise InvalidItems unless raw.is_a?(Array)

            params.permit(items: keys)[:items] || []
          end
        end
      end
    end
  end
end
