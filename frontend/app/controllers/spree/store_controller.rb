module Spree
  class StoreController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order

    def unauthorized
      render 'spree/shared/unauthorized', :layout => Spree::Config[:layout], :status => 401
    end

    protected
      def config_locale
        Spree::Frontend::Config[:locale]
      end
  end
end

