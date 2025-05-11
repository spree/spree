module Spree
  module Admin
    class PageLinksController < ResourceController
      include Spree::Admin::PageBuilderConcern

      before_action :load_parent

      create.before :set_defaults

      def destroy
        @page_link.destroy
      end

      private

      def collection_url
        @collection_url ||= if @parent.is_a?(Spree::PageSection)
                              spree.edit_admin_page_section_path(@parent)
                            elsif @parent.is_a?(Spree::PageBlock)
                              spree.edit_admin_page_section_block_path(@parent.section, @parent)
                            end
      end

      def load_parent
        @parent ||= if @page_link&.persisted?
                      @page_link.parent
                    elsif params[:block_id].present?
                      Spree::PageBlock.find(params[:block_id])
                    elsif params[:page_section_id].present?
                      Spree::PageSection.find(params[:page_section_id])
                    end
      end

      def set_defaults
        raise ActiveRecord::RecordNotFound unless @parent

        @page_link.parent = @parent
        @page_link.linkable_type ||= @parent.default_linkable_type
        @page_link.linkable ||= @parent.default_linkable_resource
      end

      # for create action we don't pass the page_link at all
      def permitted_resource_params
        if params[:page_link].present?
          params.require(:page_link).permit(permitted_page_link_attributes)
        else
          {}
        end
      end
    end
  end
end
