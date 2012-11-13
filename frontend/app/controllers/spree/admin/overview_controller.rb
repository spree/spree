# this clas was inspired (heavily) from the mephisto admin architecture
module Spree
  module Admin
    class OverviewController < Spree::Admin::BaseController
      #todo, add rss feed of information that is happening

      def index
        @users = User.all
      end

    end
  end
end
