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

      def payment_source_name(payment)
        return if payment.source.blank?

        source_class = payment.source.class
        if source_class.respond_to?(:display_name)
          source_class.display_name
        else
          source_class.name.demodulize.split(/(?=[A-Z])/).join(' ')
        end
      end
    end
  end
end
