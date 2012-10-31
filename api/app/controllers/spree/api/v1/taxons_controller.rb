module Spree
  module Api
    module V1
      class TaxonsController < Spree::Api::V1::BaseController
        def index
          @taxons = taxonomy.root.children
        end

        def jstree
          show
        end

        def show
          @taxon = taxon
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
          @taxonomy ||= Taxonomy.find(params[:taxonomy_id])
        end

        def taxon
          @taxon ||= taxonomy.taxons.find(params[:id])
        end

      end
    end
  end
end
