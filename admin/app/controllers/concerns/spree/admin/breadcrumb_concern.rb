module Spree
  module Admin
    module BreadcrumbConcern
      extend ActiveSupport::Concern

      included do
        class_attribute :breadcrumb_icon
        before_action :add_breadcrumb_icon_instance_var
      end

      class_methods do
        def add_breadcrumb_icon(icon_name)
          self.breadcrumb_icon = icon_name
        end
      end

      def add_breadcrumb_icon_instance_var
        @breadcrumb_icon = self.class.breadcrumb_icon
      end
    end
  end
end
