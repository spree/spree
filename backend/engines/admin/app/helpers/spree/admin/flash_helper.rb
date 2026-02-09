module Spree
  module Admin
    module FlashHelper
      def admin_flash_class_for(flash_type)
        {
          success: 'alert-success',
          error: 'alert-danger',
          warning: 'alert-warning',
          notice: 'alert-success',
          alert: 'alert-danger'
        }[flash_type.to_sym]
      end
    end
  end
end
