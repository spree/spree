module Spree
  module CheckoutHelper
    def checkout_submit_tag
      submit_label_key = @order.confirm? ? :place_order : :save_and_continue
      submit_tag Spree.t(submit_label_key), class: 'btn btn-primary text-uppercase font-weight-bold w-100 checkout-content-save-continue-button',
                                            id: 'checkout-submit'
    end
  end
end
