module Spree
  module Admin
    module OverviewHelper

      def jirafe_locale_links
        Spree::Admin::OverviewController::JIRAFE_LOCALES.collect do |langage, locale|
          link_to t(langage), admin_path(:locale => locale)
        end
      end

    end
  end
end
