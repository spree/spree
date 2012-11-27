module Spree
  module Admin
    module OverviewHelper

      def jirafe_locale_links
        Spree::Admin::OverviewController::JIRAFE_LOCALES.collect do |langage, locale|
          link_to image_tag("flags/#{locale.split('_')[1].downcase}.png", :alt => langage.to_s.titleize), admin_path(:locale => locale), :class => 'with-tip', :title => langage.to_s.titleize, :data => {:'tip-color' => 'green'}
        end
      end

    end
  end
end
