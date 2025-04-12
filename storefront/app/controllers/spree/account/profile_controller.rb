module Spree
  module Account
    class ProfileController < BaseController
      # GET /account/profile
      def edit; end

      # PUT /account/profile
      def update
        if try_spree_current_user.update(user_params)
          redirect_to spree.edit_account_profile_path, notice: Spree.t(:successfully_updated, resource: Spree.t(:account))
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:first_name, :last_name, :phone, :email)
      end
    end
  end
end
