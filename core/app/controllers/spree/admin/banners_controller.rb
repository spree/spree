module Spree
  module Admin
    class BannersController < Spree::Admin::BaseController
      def dismiss
        if request.xhr? and params[:id]
          spree_current_user.dismiss_banner(params[:id])
          render :nothing => true
        end
      end
    end
  end
end
