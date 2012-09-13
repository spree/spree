module Spree
  module Admin
    class BannersController < Spree::Admin::BaseController
      def dismiss
        if request.xhr? and params[:banner_id]
          if user = try_spree_current_user
            user.dismiss_banner(params[:banner_id])
          end
          render :nothing => true
        end
      end
    end
  end
end
