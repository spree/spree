module Spree
  module Api
    module V3
      module Admin
        module Orders
          class GiftCardsController < BaseController
            skip_before_action :set_resource, raise: false

            # POST /api/v3/admin/orders/:order_id/gift_cards
            #
            # Body: { code: String }
            def create
              with_order_lock do
                gift_card = find_gift_card!
                return unless gift_card

                result = @parent.apply_gift_card(gift_card)

                if result.success?
                  render json: serializer_class.new(gift_card).to_h, status: :created
                else
                  render_service_error(result.error)
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/gift_cards/:id
            def destroy
              with_order_lock do
                result = @parent.remove_gift_card

                if result.success?
                  head :no_content
                else
                  render_service_error(result.error)
                end
              end
            end

            protected

            def model_class
              Spree::GiftCard
            end

            def serializer_class
              Spree.api.admin_gift_card_serializer
            end

            private

            def find_gift_card!
              gift_card = current_store.gift_cards.find_by(code: params[:code]&.downcase)

              if gift_card.nil?
                render_error(code: ERROR_CODES[:gift_card_not_found], message: Spree.t(:gift_card_not_found), status: :not_found)
                return
              end

              if gift_card.expired?
                render_error(code: ERROR_CODES[:gift_card_expired], message: Spree.t(:gift_card_expired), status: :unprocessable_content)
                return
              end

              if gift_card.redeemed?
                render_error(code: ERROR_CODES[:gift_card_already_redeemed], message: Spree.t(:gift_card_already_redeemed), status: :unprocessable_content)
                return
              end

              gift_card
            end
          end
        end
      end
    end
  end
end
