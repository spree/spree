module Spree
  module Admin
    class SectionsController < ResourceController
      belongs_to 'spree/page'

      before_action :load_data

      def collection_url
        spree.edit_admin_page_path(@page)
      end

      def location_after_save
        spree.edit_admin_page_section_path(@page, @section)
      end

      def remove_icon
        if @section.icon&.destroy
          flash[:success] = Spree.t('notice_messages.icon_removed')
          redirect_to spree.edit_admin_page_section_path(@page, @section)
        else
          flash[:error] = Spree.t('errors.messages.cannot_remove_icon')
          render :edit
        end
      end

      private

      def load_data
        @section_widths = Spree::Section::SECTION_WIDTHS
      end
    end
  end
end
