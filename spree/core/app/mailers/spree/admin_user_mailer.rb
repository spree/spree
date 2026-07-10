module Spree
  # Auth emails for admin users. Reached two ways: the legacy Rails admin's
  # Devise flow (via Spree::AdminUserMethods::DeviseNotifications) and the Admin
  # API's `admin_user.password_reset_requested` event (dashboard SPA).
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

    def confirmation_email(admin_user, token, store)
      @user = admin_user
      @current_store = store
      @confirmation_url = confirmation_url(token, store)

      with_store_locale(store, preferred_locale(admin_user, store)) do
        mail(
          to: admin_user.email,
          subject: "#{store.name} #{Spree.t('admin_user_mailer.confirmation_email.subject')}",
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

    # The dashboard SPA passes a validated redirect URL (token appended as a
    # query param); the legacy Devise flow links to its own edit-password route
    # when the host app installed it.
    def password_reset_url(token, store, redirect_url)
      return append_token(redirect_url, token) if redirect_url.present?

      if spree.respond_to?(:edit_admin_user_password_url)
        spree.edit_admin_user_password_url(reset_password_token: token, host: store.formatted_url)
      else
        append_token(store.formatted_url, token)
      end
    end

    def confirmation_url(token, store)
      if spree.respond_to?(:admin_user_confirmation_url)
        spree.admin_user_confirmation_url(confirmation_token: token, host: store.formatted_url)
      else
        append_token(store.formatted_url, token)
      end
    end
  end
end
