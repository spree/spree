module Spree
  module Api
    module V3
      module Store
        module Orders
          # Customer self-service exchanges: a shipped unit goes back and
          # another variant of the same product comes out — a different size
          # or colour. Anything else is a return and a new order: the portal
          # cannot take a payment, and a replacement that costs more leaves a
          # balance only the merchant can collect.
          #
          # Eligibility is the `exchanges.create.validate` hook's, which core
          # fills with the same validators as returns.
          class ExchangesController < Store::ResourceController
            include Spree::Api::V3::Store::CustomerPostSale
            include Spree::Api::V3::Store::CustomerWithdrawal

            before_action :set_resource, only: [:show, :update, :destroy, :cancel]

            request_params 'CreateExchangeParams', action: :create do |body|
              body.attribute :items, :array, required: true do |item|
                item.attribute :fulfillment_item_id, :id, required: true, description: 'The shipped unit coming back.'
                item.attribute :new_variant_id, :id, required: true,
                  description: 'A purchasable variant of the same product as the unit coming back.'
                item.attribute :quantity, :integer, required: true
              end
              body.attribute :reason_id, :id, description: "One of the store's return reasons."
              body.attribute :memo, :string
            end

            def create
              items = items_for_create
              return render_invalid_replacement if items.any? { |item| item[:new_variant].nil? }

              result = Spree.exchange_create_workflow.call(
                order: @parent,
                items: items,
                reason: reason_for_create,
                memo: create_params[:memo]
              )

              render_result(result, status: :created)
            end

            protected

            def model_class
              Spree::Exchange
            end

            def serializer_class
              Spree.api.exchange_serializer
            end

            def scope
              @parent.exchanges.order(created_at: :desc)
            end

            def collection_includes
              [{ exchange_line_items: [:original_variant, { new_variant: :prices }] }]
            end

            def cancel_workflow
              Spree.exchange_cancel_workflow
            end

            def workflow_record_key
              :exchange
            end

            private

            def items_for_create
              Array(create_params[:items]).map do |item|
                unit = fulfillment_item_for(item[:fulfillment_item_id])

                { fulfillment_item: unit, new_variant: replacement_for(unit, item[:new_variant_id]), quantity: item[:quantity].to_i }
              end
            end

            # Looked up through the unit's own product, so a variant of another
            # product — or another store's — is refused without saying which.
            # It must also be on sale, in stock and priced in the order's
            # currency, as it would be in a cart.
            def replacement_for(unit, variant_id)
              variant = unit.variant.product&.variants&.find_by_prefix_id(variant_id)
              return unless variant&.available? && variant.purchasable?

              variant if variant.price_in(@parent.currency)&.amount.present?
            end

            def render_invalid_replacement
              errors = ActiveModel::Errors.new(Spree::Exchange.new)
              errors.add(:base, :invalid_replacement, message: I18n.t('spree.return_errors.invalid_replacement'))
              render_validation_error(errors)
            end
          end
        end
      end
    end
  end
end
