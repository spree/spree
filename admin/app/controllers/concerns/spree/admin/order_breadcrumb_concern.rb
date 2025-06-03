module Spree
  module Admin
    module OrderBreadcrumbConcern
      extend ActiveSupport::Concern

      included do
        add_breadcrumb Spree.t(:orders), :admin_orders_path
        add_breadcrumb_icon 'inbox'
      end
    end
  end
end
