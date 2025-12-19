module Spree
  module PageSections
    class RelatedProducts < Spree::PageSection
      before_validation :make_heading_size_valid
      before_validation :make_alignment_valid

      preference :heading, :string, default: Spree.t('page_sections.related_products.heading_default')
      preference :heading_size, :string, default: 'medium'
      preference :heading_alignment, :string, default: 'left'
      preference :description_alignment, :string, default: 'left'
      preference :max_products_to_show, :integer, default: 10

      def icon_name
        'tags'
      end

      def lazy?
        true
      end

      def layout
        'swiper'
      end

      def lazy_path(variables)
        section_id = variables[:section].id
        url_options = variables[:url_options] || {}

        if variables[:product].present?
          product_id = variables[:product].id
          Spree::Core::Engine.routes.url_helpers.related_product_path(
            product_id,
            section_id: section_id,
            **url_options
          )
        elsif variables[:post].present?
          post_id = variables[:post].id
          Spree::Core::Engine.routes.url_helpers.related_products_post_path(
            post_id,
            section_id: section_id,
            **url_options
          )
        end
      end

      private

      def make_alignment_valid
        self.preferred_heading_alignment = 'left' unless %w[left center right].include?(preferred_heading_alignment)
        self.preferred_description_alignment = 'left' unless %w[left center right].include?(preferred_description_alignment)
      end

      def make_heading_size_valid
        self.preferred_heading_size = 'small' unless %w[small medium large].include?(preferred_heading_size)
      end
    end
  end
end
