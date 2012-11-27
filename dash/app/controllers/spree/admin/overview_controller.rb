module Spree
  class Admin::OverviewController < Admin::BaseController

    JIRAFE_LOCALES = { :english => 'en_US',
                       :french => 'fr_FR',
                       :german => 'de_DE',
                       :japanese => 'ja_JA' }

    def index
      if JIRAFE_LOCALES.values.include? params[:locale]
        Spree::Dash::Config.locale = params[:locale]
      end
    end

  end
end
