module Spree
  module Admin
    module PostsHelper
      def post_authors_select_options
        current_store.users.map { |user| [user.name, user.id] }
      end
    end
  end
end
