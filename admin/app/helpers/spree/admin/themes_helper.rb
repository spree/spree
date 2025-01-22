module Spree
  module Admin
    module ThemesHelper
      def available_themes
        @available_themes ||= Spree::Theme.available_themes.sort_by(&:name).reject { |theme_class| current_store.themes.any? { |theme| theme.class.to_s == theme_class.to_s } }
      end
    end
  end
end
