# this clas was inspired (heavily) from the mephisto admin architecture
module Spree
  module Admin
    class OverviewController < Spree::Admin::BaseController
      def index
        @users = User.all
      end

    end
  end
end
