module Spree
  module Admin
    module MultiStoreHelper
      def available_stores
        scope = Spree::Store.accessible_by(current_ability, :manage).includes(:logo_attachment, :favicon_image_attachment)
        scope = scope.includes(:default_custom_domain) if Spree::Store.reflect_on_association(:default_custom_domain)
        @available_stores ||= scope
      end
    end
  end
end
