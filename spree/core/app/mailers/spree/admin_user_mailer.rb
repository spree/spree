module Spree
  # Auth emails for admin users. Reached via the Admin API's
  # `admin_user.password_reset_requested` event (dashboard SPA), delivered by
  # Spree::AdminUserEmailSubscriber.
  class AdminUserMailer < BaseMailer
    def password_reset_email(admin_user, token, store, redirect_url: nil)
      @user = admin_user
      @current_store = store
      @reset_url = password_reset_url(token, store, redirect_url)

      with_store_locale(store, preferred_locale(admin_user, store)) do
        mail(
          to: admin_user.email,
          subject: "#{store.name} #{Spree.t('admin_user_mailer.password_reset_email.subject')}",
          store_url: store.formatted_url
        )
      end
    end

    private

    # Locale chain for admin auth emails:
    # the admin's own dashboard language (persisted by the profile/language
    # switcher via `PATCH /api/v3/admin/me`) → the store's configured admin
    # locale → nil, which lets with_store_locale fall back to the store's
    # default (storefront) locale. Blank or unavailable values fall through.
    def preferred_locale(admin_user, store)
      [admin_user.try(:selected_locale), store&.preferred_admin_locale]
        .find { |locale| available_locale?(locale) }
    end

    def available_locale?(locale)
      locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
    end

    # The dashboard SPA passes a validated redirect URL; the token is appended as
    # a query param, falling back to the store URL.
    def password_reset_url(token, store, redirect_url)
      append_token(redirect_url.presence || store.formatted_url, token)
    end
  end
end
