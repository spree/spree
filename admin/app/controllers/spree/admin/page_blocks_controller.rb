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
        allowed_types = Rails.application.config.spree.page_blocks.map(&:to_s)
        page_block_type = params.dig(:page_block, :type)

        if allowed_types.include?(page_block_type) && page_block_type.safe_constantize.present?
          @page_block = page_block_type.constantize.new
          @page_block.section = @page_section
          @page_block.save!
        end
      end
    end
  end
end
