module Spree
  module Admin
    class BannersController < Spree::Admin::BaseController
      def dismiss
        if params[:id]
          if user = try_spree_current_user
            user.dismiss_banner(params[:id])
          end
        end
        render :nothing => true
      end
    end
  end
end
