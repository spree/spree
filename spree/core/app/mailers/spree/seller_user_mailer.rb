module Spree
  # Auth emails for seller panel users. Reached via the Seller API's
  # `seller_user.password_reset_requested` event, delivered by
  # Spree::SellerUserEmailSubscriber.
  #
  # Separate from AdminUserMailer even though both address the same user class:
  # what differs is which panel the link opens, and sending a seller to the
  # staff dashboard would land them on a form they cannot submit.
  class SellerUserMailer < BaseMailer
    def password_reset_email(seller_user, token, store, redirect_url: nil)
      @user = seller_user
      @current_store = store
      @reset_url = password_reset_url(token, store, redirect_url)

      with_store_locale(store, preferred_locale(seller_user, store)) do
        mail(
          to: seller_user.email,
          subject: "#{store.name} #{Spree.t('seller_user_mailer.password_reset_email.subject')}",
          store_url: store.formatted_url
        )
      end
    end

    private

    # The seller's own panel language, then the store's admin locale, then nil —
    # which lets with_store_locale fall back to the store's default.
    def preferred_locale(seller_user, store)
      [seller_user.try(:selected_locale), store&.preferred_admin_locale]
        .find { |locale| available_locale?(locale) }
    end

    def available_locale?(locale)
      locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
    end

    # The panel passes a validated redirect URL when it has one. Without it the
    # panel origin is resolved server-side rather than falling back to the store
    # URL: a storefront link cannot reset a seller password, and the marketplace
    # may never have added the panel to its allowed origins.
    def password_reset_url(token, store, redirect_url)
      target = redirect_url.presence || "#{Spree::Sellers::PanelUrl.call(store: store)}/reset-password"

      append_token(target, token)
    end
  end
end
