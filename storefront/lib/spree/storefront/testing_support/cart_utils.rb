module Spree
  module Storefront
    module TestingSupport
      module CartUtils
        def add_to_cart(product, goto_checkout = false)
          visit spree.product_path(product)

          click_button Spree.t(:add_to_cart)
          wait_for_turbo
          expect(page).to have_link('Checkout')

          def view_cart
            visit spree.cart_path
          end

          def click_checkout
            click_link 'Checkout'
            expect(page).to have_content('Contact information').and have_content('Shipping Address')
          end

          if block_given?
            yield
          else
            goto_checkout ? click_checkout : view_cart
          end
        end
      end
    end
  end
end
