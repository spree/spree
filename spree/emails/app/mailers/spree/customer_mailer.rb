module Spree
  class CustomerMailer < BaseMailer
    # Password reset requested through the Store API (`customer.password_reset_requested`).
    # The link goes to the validated redirect URL when the storefront supplied one,
    # falling back to the store's storefront URL, with the reset token appended.
    def password_reset_email(user, reset_token, store, redirect_url: nil)
      @user = user
      @current_store = store
      base_url = redirect_url.presence || store.storefront_url
      @reset_url = append_token(base_url, reset_token)

      with_store_locale(store) do
        mail_template(
          { customer: email_data(user, Spree.api.customer_serializer), reset_url: @reset_url },
          to: user.email, store_url: store.storefront_url
        )
      end
    end

    # The finished subject access export (GDPR Art. 15). The link is signed
    # and expires with the request, so the file is reachable by the person who
    # asked for it and not by anyone who later reads the mailbox.
    def data_export_email(data_request)
      @data_request = data_request
      @current_store = data_request.store
      # A store route rather than a raw storage URL: a signed storage link
      # cannot be built off-request on the Disk service, and mailing one would
      # put a direct object address in an inbox where it outlives the request.
      @download_url = Spree::Api::DataRequestUrls.download_url(data_request, @current_store.formatted_url)
      @expires_at = data_request.expires_at

      with_store_locale(@current_store) do
        mail_template(
          { download_url: @download_url, expires_at: @expires_at&.iso8601 },
          to: data_request.email, store_url: @current_store.storefront_url
        )
      end
    end
  end
end
