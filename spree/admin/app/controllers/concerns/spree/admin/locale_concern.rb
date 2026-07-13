module Spree
  module Admin
    # Decouples the admin UI language from the store's content language.
    #
    # `I18n.locale` drives the UI chrome (`Spree.t` labels) and follows the
    # staff member's chosen admin language. `Mobility.locale` and
    # `Spree::Current.content_locale` drive translated record fields
    # (product/store names) and are pinned to the store's content locale —
    # otherwise switching the admin to, say, Polish would make every
    # Mobility-backed field fall back to nil for stores that don't translate
    # their catalog into Polish.
    #
    # Shared by `Spree::Admin::BaseController` and the Devise-based pre-auth
    # controllers (`UserSessionsController`), which can't inherit admin
    # behavior via the controller chain — hence a concern both include.
    # Devise-based includers opt into the login-screen locale handling with
    # `before_action :set_login_locale`.
    module LocaleConcern
      extend ActiveSupport::Concern

      # Cookie storing the admin UI language chosen on the login screen, so a
      # guest's pre-auth selection carries into the authenticated session. A
      # signed-in user's saved `selected_locale` still takes precedence.
      ADMIN_LOCALE_COOKIE = :spree_admin_locale

      private

      # Pin content reads to the store's content locale (its default locale),
      # independent of the chosen UI language. Request-local state only — the
      # content locale must never be written to the process-global
      # `I18n.default_locale`, which every thread in the server process shares.
      # The fallback for storeless hosts lives in the
      # `Spree::Current#content_locale` reader.
      def pin_content_locale!
        Spree::Current.content_locale = (current_store&.default_locale if defined?(current_store))
        Mobility.locale = Spree::Current.content_locale
      end

      # Pre-auth locale handling for Devise-based screens, where the
      # `set_locale` before_action from `Spree::Core::ControllerHelpers::Locale`
      # never runs. A supported `?locale=` is applied and persisted; an
      # unsupported one is ignored rather than shadowing an already-valid
      # cookie. Falls back to the cookie set on a previous visit, then to the
      # application default — always an explicit assignment, so a plain visit
      # can never render in whatever locale the thread's previous request
      # happened to set.
      def set_login_locale
        pin_content_locale!

        if supported_admin_locale?(params[:locale])
          cookies[ADMIN_LOCALE_COOKIE] = { value: params[:locale], expires: 1.year }
          I18n.locale = params[:locale]
        elsif supported_admin_locale?(admin_locale_cookie)
          I18n.locale = admin_locale_cookie
        else
          I18n.locale = I18n.default_locale
        end
      end

      def admin_user_selected_locale
        defined?(try_spree_current_user) && try_spree_current_user&.selected_locale
      end

      def admin_locale_cookie
        cookies[ADMIN_LOCALE_COOKIE]
      end

      # True when the admin UI is actually translated into +locale+
      # (`Spree.available_locales`) — distinct from the storefront's
      # store-scoped `supported_locale?`.
      def supported_admin_locale?(locale)
        locale.present? && Spree.available_locales.map(&:to_s).include?(locale.to_s)
      end
    end
  end
end
