module Spree
  module PageSections
    class FeaturedTaxon < Spree::PageSection
      scope :by_taxon_id, lambda { |taxon_ids|
        queries = [*taxon_ids].map do |taxon_id|
          where("#{Spree::PageSections::FeaturedTaxon.table_name}.preferences LIKE ?", "%taxon_id: '#{taxon_id}'%")
        end

        queries.reduce(:or)
      }

      has_rich_text :description

      before_validation :make_heading_size_valid
      before_validation :make_alignment_valid
      before_validation :make_taxon_id_valid

      preference :heading, :string, default: Spree.t('page_sections.featured_taxon.heading_default')
      preference :heading_size, :string, default: 'large'
      preference :heading_alignment, :string, default: 'left'
      preference :description_alignment, :string, default: 'left'
      preference :use_description_from_admin, :boolean, default: true
      preference :show_taxon_image, :boolean, default: true
      preference :show_more_button, :boolean, default: true
      preference :taxon_id, :string, default: ''
      preference :max_products_to_show, :integer, default: 20
      preference :button_style, :string, default: 'primary'
      preference :button_text_color, :string, default: nil
      preference :button_background_color, :string, default: nil
      preference :button_text, :string, default: Spree.t('page_sections.featured_taxon.button_text_default')

      def icon_name
        'tags'
      end

      def lazy?
        !Rails.env.test?
      end

      def taxon
        @taxon ||= store.taxons.find_by(id: preferred_taxon_id) if preferred_taxon_id.present?
      end

      def description_to_use
        @description_to_use ||= preferred_use_description_from_admin && description.blank? ? taxon&.description : description
      end

      def display_name
        @display_name ||= preferred_heading.present? ? "#{preferred_heading} - #{name}" : name
      end

      def products(currency)
        Spree::Deprecation.warn('FeaturedTaxon#products is deprecated and will be removed in Spree 6.0. Please use taxon_products helper method instead')

        @products ||= begin
          finder_params = {
            store: store,
            filter: { taxons: preferred_taxon_id },
            currency: currency,
            sort_by: 'default'
          }

          products_finder = Spree::Dependencies.products_finder.constantize
          products_finder.new(scope: store.products, params: finder_params).execute.limit(preferred_max_products_to_show)
        end
      end

      private

      def make_taxon_id_valid
        self.preferred_taxon_id = preferred_taxon_id.presence || store.taxons.where(depth: 1).first&.id
      end

      def set_heading
        return unless collection_id_changed?

        self.heading = collection&.title
      end

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
