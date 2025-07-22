module Spree
  module Admin
    class PageSectionsController < ResourceController
      include Spree::Admin::PageBuilderConcern

      before_action :load_pageable, only: %i[new create index]

      def create
        page_section_type = params.dig(:page_section, :type)
        allowed_types = available_page_section_types.map(&:to_s)

        if allowed_types.include?(page_section_type)
          # Find the actual class from our allowed types rather than using constantize
          section_class = available_page_section_types.find { |type| type.to_s == page_section_type }

          if section_class
            @page_section = section_class.new(permitted_resource_params)
            @page_section.pageable = @pageable
            @page_section.save!
          end
        end
      end

      def destroy
        @page_section.destroy if @page_section.can_be_deleted?
      end

      def move_higher
        if @page_section.first?
          head :ok
        else
          @page_section.move_higher
        end
      end

      def move_lower
        if @page_section.last?
          head :ok
        else
          @page_section.move_lower
        end
      end

      def restore_design_settings_to_defaults
        @page_section.restore_design_settings_to_defaults
      end

      private

      def load_pageable
        @pageable = if @page_section.present? && @page_section.pageable.present?
                      @page_section.pageable
                    elsif params[:page_id].present?
                      current_store.theme_page_previews.friendly.find_by(id: params[:page_id]) ||
                        current_store.page_previews.friendly.find(params[:page_id])
                    elsif params[:theme_id].present?
                      current_store.theme_previews.find(params[:theme_id])
                    end
      end

      def available_page_section_types
        return [] unless @pageable.present?

        if @pageable.is_a?(Spree::Theme)
          @pageable.available_page_sections
        elsif @pageable.respond_to?(:theme)
          @pageable.theme.available_page_sections
        else
          []
        end
      end

      def permitted_resource_params
        params.require(:page_section).permit(
          permitted_page_section_attributes +
          [link_attributes: permitted_page_link_attributes + [:id]] +
          @object.preferences.keys.map { |key| "preferred_#{key}" }
        )
      end
    end
  end
end
