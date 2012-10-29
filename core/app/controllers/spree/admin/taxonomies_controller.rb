module Spree
  module Admin
    class TaxonomiesController < ResourceController
      respond_to :json, :only => [:get_children]

      def get_children
        @taxons = Taxon.find(params[:parent_id]).children

        respond_with(@taxons)
      end

      private

      def location_after_save
        if @taxonomy.created_at == @taxonomy.updated_at
          edit_admin_taxonomy_url(@taxonomy)
        else
          admin_taxonomies_url
        end
      end
    end
  end
end
