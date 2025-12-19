module Spree
  module Admin
    class PageBlocksController < Spree::Admin::ResourceController
      include Spree::Admin::PageBuilderConcern

      belongs_to 'spree/page_section', find_by: :id

      def destroy
        @page_block.destroy
      end

      def move_higher
        if @page_block.first?
          head :ok
        else
          @page_block.move_higher
        end
      end

      def move_lower
        if @page_block.last?
          head :ok
        else
          @page_block.move_lower
        end
      end

      def create
        page_block_type = params.dig(:page_block, :type)
        allowed_type = allowed_types.find { |type| type.to_s == page_block_type }

        if allowed_type
          @page_block = allowed_type.new
          @page_block.section = @page_section
          @page_block.save!
        end
      end

      private

      def allowed_types
        [
          *Spree.page_builder.page_blocks,
          *parent&.available_blocks_to_add
        ].uniq.sort_by(&:name)
      end

      def permitted_resource_params
        params.require(:page_block).permit(
          permitted_page_block_attributes +
          [link_attributes: permitted_page_link_attributes + [:id]] +
          @object.preferences.keys.map { |key| "preferred_#{key}" } +
          [preferred_metafield_definition_ids: []]
        )
      end
    end
  end
end
