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
          from: from_address,
          subject: "#{store.name} #{Spree.t('customer_mailer.password_reset_email.subject')}",
          store_url: store.storefront_url
        )
      end
    end
  end
end
