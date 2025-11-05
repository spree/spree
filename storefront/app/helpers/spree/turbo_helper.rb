module Spree
  module TurboHelper
    def spree_turbo_update_flashes
      turbo_stream.update 'flash' do
        render 'spree/shared/flashes'
      end
    end

    def spree_turbo_update_cart(order = current_order)
      [
        turbo_stream.update_all('.cart-counter', order&.item_count&.positive? ? order&.item_count : ''),
        turbo_stream.update_all('.cart-total', order&.display_item_total.to_s)
      ].join.html_safe
    end
  end
end
