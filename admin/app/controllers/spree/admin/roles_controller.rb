module Spree
  module Admin
    class RolesController < ResourceController
      before_action :load_parent

      private

      def load_parent
        @parent = current_store
      end
    end
  end
end
