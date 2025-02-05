module Spree
  module Admin
    module PostsHelper
      def post_authors_select_options
        Spree.admin_user_class.spree_admin.map { |user| [user.name, user.id] }
      end
    end
  end
end
