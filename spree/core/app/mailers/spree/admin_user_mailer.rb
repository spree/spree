module Spree
  # Auth emails for admin users. Reached via the Admin API's
  # `admin_user.password_reset_requested` event (dashboard SPA), delivered by
  # Spree::AdminUserEmailSubscriber.
  class AdminUserMailer < BaseMailer
    def password_reset_email(admin_user, token, store, redirect_url: nil)
      @user = admin_user
      @current_store = store
      @reset_url = password_reset_url(token, store, redirect_url)

      with_store_locale(store, staff_locale(admin_user, store)) do
        mail_template(
          { user: email_data(admin_user, Spree::Emails::UserSerializer), reset_url: @reset_url },
          to: admin_user.email, store_url: store.formatted_url
        )
      end
    end

    private

    # The dashboard SPA passes a validated redirect URL; the token is appended as
    # a query param, falling back to the dashboard's own reset page.
    def password_reset_url(token, store, redirect_url)
      append_token(redirect_url.presence || "#{Spree::Stores::DashboardUrl.call(store: store)}/reset-password", token)
    end
  end
end
