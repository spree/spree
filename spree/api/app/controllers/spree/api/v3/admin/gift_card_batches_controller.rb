module Spree
  module Api
    module V3
      module Admin
        # Admin bulk-issue endpoint for `Spree::GiftCardBatch`. Creating a
        # batch synchronously generates the `codes_count` gift cards inline
        # (or kicks off a background job when the count exceeds
        # `Spree.config.gift_card_batch_web_limit`, default 500). Read-only
        # access lives behind `list`/`show` so the SPA can surface batch
        # context on the gift cards index (filter chip, batch chip on rows).
        class GiftCardBatchesController < ResourceController
          scoped_resource :gift_cards

          request_params :gift_card_batch do
            string :prefix, required: :create, example: 'WELCOME',
                            description: 'Lowercased and prepended to every generated code.'
            decimal :amount, required: :create, example: '25.00',
                             description: 'The amount of each card, greater than zero.'
            integer :codes_count, required: :create, example: 100,
                                  description: 'How many cards to generate. Capped at `gift_card_batch_limit`; batches over `gift_card_batch_web_limit` generate in the background.'
            string :currency, example: 'USD', description: 'ISO 4217 currency code. Defaults to the store currency.'
            date :expires_at, nullable: true, example: '2030-12-31'
          end

          protected

          def model_class
            Spree::GiftCardBatch
          end

          def serializer_class
            Spree.api.admin_gift_card_batch_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
