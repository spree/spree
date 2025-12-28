module Spree
  module Admin
    module StorefrontBreadcrumbConcern
      extend ActiveSupport::Concern

      included do
        add_breadcrumb_icon 'building-store'
        add_breadcrumb Spree.t('admin.storefront'), :admin_themes_path
      end
    end
  end
end
