module Spree
  module Admin
    # Decouples the admin UI language from the store's content language.
    #
    # `I18n.locale` drives the UI chrome (`Spree.t` labels) and follows the
    # staff member's chosen admin language. `Mobility.locale` drives translated
    # record fields (product/store names) and is pinned to the store's content
    # locale — otherwise switching the admin to, say, Polish would make every
    # Mobility-backed field fall back to nil for stores that don't translate
    # their catalog into Polish.
    #
    # Shared by `Spree::Admin::BaseController` and `UserSessionsController`; the
    # latter subclasses `Devise::SessionsController`, so it can't inherit this
    # via the controller chain — hence a concern both include.
    module LocaleConcern
      extend ActiveSupport::Concern

      # Cookie storing the admin UI language chosen on the login screen, so a
      # guest's pre-auth selection carries into the authenticated session. A
      # signed-in user's saved `selected_locale` still takes precedence.
      ADMIN_LOCALE_COOKIE = :spree_admin_locale

      private

      # The store's content locale — the language record content (product names,
      # etc.) is authored in — independent of the chosen admin UI language.
      def content_locale
        (defined?(current_store) && current_store&.default_locale.presence) || I18n.default_locale
      end

      # Read all record content in the store's content locale, independent of
      # the chosen UI language.
      def pin_content_locale!
        Mobility.locale = content_locale
      end

      # Keep `I18n.default_locale` on the store's content locale so it matches
      # `Mobility.locale` (set by `pin_content_locale!`). The admin overrides
      # `default_locale` to return the UI language, which the inherited
      # `set_locale` leaks into the process-global `I18n.default_locale`. When it
      # diverges from `Mobility.locale`, Mobility's `column_fallback` JOINs the
      # translations table instead of reading the base column, breaking the
      # admin's ordered + `DISTINCT` listings.
      def align_i18n_default_locale_to_content!
        I18n.default_locale = content_locale
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
