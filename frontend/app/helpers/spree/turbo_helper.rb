module Spree
  module TurboHelper
    def spree_turbo_update_flashes
      turbo_stream.update 'flash' do
        flash_messages
      end
    end

    def spree_turbo_update_cart(order = current_order)
      turbo_stream.update 'link-to-cart' do
        render 'spree/shared/cart', class: 'd-inline-block cart-icon', size: 36, item_count: order.item_count
      end
    end
  end
end
