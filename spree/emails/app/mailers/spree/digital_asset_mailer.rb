module Spree
  class DigitalAssetMailer < BaseMailer
    helper Spree::MailHelper
    helper Spree::DigitalAssetHelper

    # Sent once an order's downloads are ready. Kept separate from the order
    # confirmation so it can be re-sent on its own, and so a storefront that
    # replaces the confirmation email does not silently lose the links.
    def files_ready_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      @digital_links = @order.digital_links
      return if @digital_links.empty?

      current_store = @order.store
      with_store_locale(current_store, @order.locale) do
        subject = order_email_subject(
          current_store,
          Spree.t('digital_asset_mailer.files_ready_email.subject'),
          @order.number,
          resend: resend
        )
        mail(to: @order.email, subject: subject, store_url: current_store.storefront_url,
             template_path: 'spree/digital_asset_mailer', template_name: 'files_ready_email')
      end
    end
  end
end
