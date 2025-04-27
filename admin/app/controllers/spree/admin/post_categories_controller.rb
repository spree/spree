module Spree
  module Admin
    class PostCategoriesController < ResourceController
      include StorefrontBreadcrumbConcern
      add_breadcrumb Spree.t(:posts), :admin_posts_path
      add_breadcrumb Spree.t(:categories), :admin_post_categories_path
    end
  end
end
