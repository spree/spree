module Spree
  module Account
    class ProfileController < BaseController
      def edit; end

      def update
        if @user.update(user_params)
          redirect_to spree.edit_account_profile_path, notice: Spree.t(:account_updated)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:title, :first_name, :last_name, :phone)
      end

      def accurate_title
        Spree.t(:my_account)
      end
    end
  end
end
