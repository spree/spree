module Spree
  module Admin
    # View helpers for the legacy admin's layout direction (`<html dir>`).
    # RTL detection itself lives on Spree::Locale (the single source of truth).
    module RtlHelper
      def rtl_locale?(locale = I18n.locale)
        Spree::Locale.new(code: locale).rtl?
      end

      def html_dir(locale = I18n.locale)
        Spree::Locale.new(code: locale).direction
      end
    end
  end
end
