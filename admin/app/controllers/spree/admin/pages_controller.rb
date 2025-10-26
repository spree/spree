module Spree
  module Admin
    class PagesController < Spree::Admin::ResourceController
      create.before :set_page
      update.after :remove_preview_from_session
      destroy.after :remove_preview_from_session
      create.after :remove_preview_from_session

      include StorefrontBreadcrumbConcern
      add_breadcrumb Spree.t(:pages), :admin_pages_path

      private

      def remove_preview_from_session
        session.delete(:page_preview_id)
      end

      def flash_message_for(object, event_sym)
        Spree.t(event_sym, resource: "#{Spree.t(:page)} \"#{object.name}\"")
      end

      def set_page
        @object = current_store.pages.custom.new
      end

      def edit_object_url(object, options = {})
        spree.edit_admin_theme_path(current_store.default_theme, page_id: object.id, **options)
      end

      def collection
        super.custom.without_previews
      end

      def permitted_resource_params
        params.require(:page).permit(permitted_page_attributes)
      end
    end
  end
end
