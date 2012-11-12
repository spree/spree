module Spree
  module Api
    class TaxonsController < Spree::Api::BaseController
      def index
        if taxonomy
          @taxons = taxonomy.root.children
        else
          if params[:ids]
            @taxons = Taxon.where(:id => params[:ids].split(","))
          else
            @taxons = Taxon.ransack(params[:q]).result
          end
        end
      end

      def show
        @taxon = taxon
      end

      def jstree
        show
      end

      def create
        authorize! :create, Taxon
        @taxon = Taxon.new(params[:taxon])
        if @taxon.save
          render :show, :status => 201
        else
          invalid_resource!(@taxon)
        end
      end

      def update
        authorize! :update, Taxon
        if taxon.update_attributes(params[:taxon])
          render :show, :status => 200
        else
          invalid_resource!(taxon)
        end
      end

      def destroy
        authorize! :delete, Taxon
        taxon.destroy
        render :text => nil, :status => 204
      end

      private

      def taxonomy
        if params[:taxonomy_id].present?
          @taxonomy ||= Taxonomy.find(params[:taxonomy_id])
        end
      end

      def taxon
        @taxon ||= taxonomy.taxons.find(params[:id])
      end

    end
  end
end
