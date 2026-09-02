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
        mail(
          to: user.email,
          subject: "#{store.name} #{Spree.t('customer_mailer.password_reset_email.subject')}",
          store_url: store.storefront_url
        )
      end
    end

    # The finished subject access export (GDPR Art. 15). The link is signed
    # and expires with the request, so the file is reachable by the person who
    # asked for it and not by anyone who later reads the mailbox.
    def data_export_email(data_request)
      @data_request = data_request
      @current_store = data_request.store
      @download_url = data_request.export_file.url(expires_in: Spree::DataRequest::DEFAULT_EXPIRY)
      @expires_at = data_request.expires_at

      with_store_locale(@current_store) do
        mail(
          to: data_request.email,
          subject: "#{@current_store.name} #{Spree.t('customer_mailer.data_export_email.subject')}",
          store_url: @current_store.storefront_url
        )
      end
    end
  end
end
