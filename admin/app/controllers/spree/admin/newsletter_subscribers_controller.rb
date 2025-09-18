module Spree
  module Admin
    class NewsletterSubscribersController < ResourceController
      add_breadcrumb_icon 'users'
      add_breadcrumb Spree.t(:customers), :admin_users_path
    end
  end
end
