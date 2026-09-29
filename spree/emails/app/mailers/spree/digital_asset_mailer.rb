module Spree
  class DigitalAssetMailer < BaseMailer
    # Sent once an order's downloads are ready. Kept separate from the order
    # confirmation so it can be re-sent on its own, and so a storefront that
    # replaces the confirmation email does not silently lose the links.
    def files_ready_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      # The template reads each link's filename and expiry, both of which reach
      # through the asset — preload rather than paying per link.
      @digital_links = @order.digital_links.includes(digital_asset: { attachment_attachment: :blob })
      return if @digital_links.empty?

      @download_host = current_store.formatted_url
      with_store_locale(current_store, @order.locale) do
        mail_template(
          { order: email_data(@order, Spree::Emails::OrderSerializer),
            downloads: downloads, resend: resend },
          to: @order.email, store_url: current_store.storefront_url
        )
      end
    end

    private

    # Download URLs carry each link's bearer token, so they are built here
    # rather than serialized. They point at the backend, not the storefront.
    def downloads
      @digital_links.map do |digital_link|
        {
          filename: digital_link.filename.to_s,
          url: Spree::Api::DigitalLinkUrls.download_url(digital_link, @download_host),
          expires_at: digital_link.expires_at&.iso8601
        }
      end
    end
  end
end
