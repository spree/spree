module Spree
  module Api
    module V3
      module Store
        module Carts
          class GiftCardsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # POST /api/v3/store/carts/:cart_id/gift_cards
            def create
              with_order_lock do
                gift_card = find_gift_card!
                return unless gift_card

                result = @cart.apply_gift_card(gift_card)

                if result.success?
                  render_cart(status: :created)
                else
                  render_service_error(result.error)
                end
              end
            end

            # DELETE /api/v3/store/carts/:cart_id/gift_cards/:id
            def destroy
              with_order_lock do
                result = @cart.remove_gift_card

                if result.success?
                  render_cart
                else
                  render_service_error(result.error)
                end
              end
            end

            private

            def find_gift_card!
              gift_card = @cart.store.gift_cards.find_by(code: permitted_params[:code]&.downcase)

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

            def permitted_params
              params.permit(:code)
            end
          end
        end
      end
    end
  end
end
