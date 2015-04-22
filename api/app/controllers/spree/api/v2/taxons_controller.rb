module Spree
  module Api
    module V2
      class TaxonsController < Spree::Api::BaseController
        def index
          if taxonomy
            @taxons = taxonomy.root.children
          else
            if params[:ids]
              @taxons = Spree::Taxon.includes(:children).accessible_by(current_ability, :read).where(id: params[:ids].split(','))
            else
              @taxons = Spree::Taxon.includes(:children).accessible_by(current_ability, :read).order(:taxonomy_id, :lft).ransack(params[:q]).result
            end
          end

          @taxons = @taxons.page(params[:page]).per(params[:per_page])

          if params["without_children"] == 1
            render json: @taxons, meta: pagination(@taxons), each_serializer: Spree::TaxonNoChildrenSerializer
          else
            render json: @taxons, meta: pagination(@taxons), each_serializer: Spree::TaxonSerializer
          end
        end

        def show
          render json: taxon
        end

        def jstree
          tree = taxon.children.map do |taxon|
            {
              data: taxon.name,
              attr: {
                id: taxon.id,
                name: taxon.name
              },
              state: 'closed'
            }
          end

          render json: tree, root: false
        end

        def create
          authorize! :create, Taxon
          @taxon = Spree::Taxon.new(taxon_params)
          @taxon.taxonomy_id = params[:taxonomy_id]
          taxonomy = Spree::Taxonomy.find_by(id: params[:taxonomy_id])

          if taxonomy.nil?
            @taxon.errors[:taxonomy_id] = I18n.t(:invalid_taxonomy_id, scope: 'spree.api')
            invalid_resource!(@taxon)
            return
          end

          @taxon.parent_id = taxonomy.root.id unless params[:taxon][:parent_id]

          if @taxon.save
            render json: @taxon, status: 201
          else
            invalid_resource!(@taxon)
          end
        end

        def update
          authorize! :update, taxon
          if taxon.update_attributes(taxon_params)
            render json: taxon
          else
            invalid_resource!(taxon)
          end
        end

        def destroy
          authorize! :destroy, taxon
          taxon.destroy
          render nothing: true, status: 204
        end

        def products
          # Returns the products sorted by their position with the classification
          # Products#index does not do the sorting.
          taxon = Spree::Taxon.find(params[:id])
          @products = taxon.products.ransack(params[:q]).result
          @products = @products.page(params[:page]).per(params[:per_page] || 500)
          render json: @products, meta: pagination(@products), root: "products"
        end

        private

        def taxonomy
          if params[:taxonomy_id].present?
            @taxonomy ||= Spree::Taxonomy.accessible_by(current_ability, :read).find(params[:taxonomy_id])
          end
        end

        def taxon
          @taxon ||= taxonomy.taxons.accessible_by(current_ability, :read).find(params[:id])
        end

        def taxon_params
          if params[:taxon] && !params[:taxon].empty?
            params.require(:taxon).permit(permitted_taxon_attributes)
          else
            {}
          end
        end
      end
    end
  end
end
