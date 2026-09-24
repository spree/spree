module Spree
  # Auth emails for admin users. Reached via the Admin API's
  # `admin_user.password_reset_requested` event (dashboard SPA), delivered by
  # Spree::AdminUserEmailSubscriber.
  class AdminUserMailer < BaseMailer
    def password_reset_email(admin_user, token, store, redirect_url: nil)
      @user = admin_user
      @current_store = store
      @reset_url = password_reset_url(token, store, redirect_url)
      problem = reset_url_problem(@reset_url)
      return log_unsent(admin_user, problem) if problem

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

    # The dashboard passes a validated redirect URL when its origin is allowed.
    # Without it the dashboard origin is resolved server-side, never from the
    # store URL: that has no reset page, so a link there cannot reset anything.
    def password_reset_url(token, store, redirect_url)
      return append_token(redirect_url, token) if redirect_url.present?

      dashboard_url = Spree::Stores::DashboardUrl.without_store_fallback(store: store)
      append_token("#{dashboard_url}/reset-password", token) if dashboard_url.present?
    end

    # Every reset link must open the dashboard's reset page over https, since it
    # carries the token. Development and test run on plain http.
    def reset_url_problem(url)
      if url.nil?
        'the dashboard address is unknown. Set SPREE_DASHBOARD_URL (or the dashboard_url preference), ' \
          "or add the dashboard's origin to the store's allowed origins."
      elsif !Rails.env.local? && !https_url?(url)
        'its reset link is not https. Use an https dashboard address in SPREE_DASHBOARD_URL ' \
          "(or the dashboard_url preference) and in the store's allowed origins."
      end
    end

    def https_url?(url)
      uri = URI.parse(url)
      uri.scheme == 'https' && uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    # Skipping rather than raising keeps the forgot-password response identical
    # for known and unknown emails.
    def log_unsent(admin_user, problem)
      Rails.logger.error("[Spree] Password reset email for admin user #{admin_user.id} was not sent: #{problem}")
    end
  end
end
