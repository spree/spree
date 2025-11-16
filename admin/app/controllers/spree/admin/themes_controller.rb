module Spree
  module Admin
    class ThemesController < ResourceController
      layout :choose_layout

      include StorefrontBreadcrumbConcern
      add_breadcrumb Spree.t(:themes), :admin_themes_path

      def edit
        @theme_preview = params[:theme_preview_id].present? ? @theme.previews.find(params[:theme_preview_id]) : @theme.create_preview
        @page = if params[:page_id].present?
                  @theme.pages.find_by(id: params[:page_id]) || current_store.pages.find(params[:page_id])
                else
                  @theme.pages.find_by(type: 'Spree::Pages::Homepage')
                end
        @page_preview = params[:page_preview_id].present? ? @page.previews.find(params[:page_preview_id]) : @page.create_preview

        session[:theme_preview_id] = @theme_preview.id
        session[:page_preview_id] = @page_preview.id
      end

      def update_with_page
        @theme_preview = @theme.previews.find(params[:theme_preview_id])
        @page_preview = @theme.page_previews.find_by(id: params[:page_preview_id]) || current_store.page_previews.find(params[:page_preview_id])

        ApplicationRecord.transaction do
          @page_preview.promote && @theme_preview.promote
        end
        flash[:success] = Spree.t('changes_published')

        redirect_to spree.edit_admin_theme_path(@theme_preview, page_id: @page_preview.id), status: :see_other
      rescue ActiveRecord::RecordInvalid
        redirect_to spree.edit_admin_theme_path(@theme_preview, page_id: @page_preview.id), alert: Spree.t('something_went_wrong')
      end

      def publish
        @theme = current_store.themes.find(params[:id])

        if @theme.update(default: true)
          flash[:success] = Spree.t('theme_is_now_live')
        else
          flash[:error] = "#{Spree.t('something_went_wrong')}: #{@theme.errors.full_messages.to_sentence}"
        end
        redirect_to spree.admin_themes_path
      end

      def clone
        @new = @theme.duplicate

        if @new.persisted?
          flash[:success] = Spree.t('theme_copied')
        else
          flash[:error] = Spree.t('theme_not_copied', error: @new.errors.full_messages.to_sentence)
        end

        redirect_to spree.admin_themes_path
      end

      private

      def choose_layout
        if action_name == 'index'
          'spree/admin'
        else
          'spree/page_builder'
        end
      end

      def update_turbo_stream_enabled?
        true
      end

      def scope
        super.without_previews.order(default: :desc)
      end

      def collection_includes
        { screenshot_attachment: :blob }
      end

      def permitted_resource_params
        params.require(:theme).permit(permitted_theme_attributes + @object.preferences.keys.map { |key| "preferred_#{key}" })
      end
    end
  end
end
