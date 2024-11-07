module Spree
  module Admin
    module PaymentsHelper
      def payment_method_name(payment)
        payment_method = payment.payment_method

        if can?(:update, payment_method)
          link_to payment_method.name, spree.edit_admin_payment_method_path(payment_method)
        else
          payment_method.name
        end
      end

      def payment_method_icon_tag(payment_method, opts = {})
        image_tag "payment_icons/#{payment_method}.svg", opts
      rescue Sprockets::Rails::Helper::AssetNotFound
      end
    end
  end
end
