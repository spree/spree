module Spree
  module Admin
    module PageBuilderConcern
      extend ActiveSupport::Concern

      included do
        before_action :set_variables
      end

      def set_variables
        @theme_preview = current_store.theme_previews.find_by(id: session[:theme_preview_id]) if session[:theme_preview_id].present?
        @theme = @theme_preview.present? ? @theme_preview.parent : current_store.default_theme
        if @theme.present? && session[:page_preview_id].present?
          @page_preview = @theme.page_previews.find_by(id: session[:page_preview_id]) ||
                            current_store.page_previews.find_by(id: session[:page_preview_id])
        end
        @page = @page_preview.parent if @page_preview
      end

      def create_turbo_stream_enabled?
        true
      end

      def update_turbo_stream_enabled?
        true
      end

      def default_url_options
        {
          theme_preview_id: session[:theme_preview_id],
          page_preview_id: session[:page_preview_id],
        }
      end

      def location_after_save
        collection_url
      end

      def collection_url
        spree.edit_admin_theme_path(@theme, page_id: @page.id)
      end
    end
  end
end
