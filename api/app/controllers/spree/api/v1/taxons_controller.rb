module Spree
  module Api
    module V1
      class TaxonsController < Spree::Api::BaseController
        def index
          @taxons = if taxonomy
                      taxonomy.root.children
                    elsif params[:ids]
                      Spree::Taxon.includes(:children).accessible_by(current_ability).where(id: params[:ids].split(','))
                    else
                      Spree::Taxon.includes(:children).accessible_by(current_ability).order(:taxonomy_id, :lft)
                    end
          @taxons = @taxons.ransack(params[:q]).result
          @taxons = @taxons.page(params[:page]).per(params[:per_page])
          respond_with(@taxons)
        end

        def show
          @taxon = taxon
          respond_with(@taxon)
        end

        def jstree
          show
        end

        def new; end

        def create
          authorize! :create, Taxon
          @taxon = Spree::Taxon.new(taxon_params)
          @taxon.taxonomy_id = params[:taxonomy_id]
          taxonomy = Spree::Taxonomy.find_by(id: params[:taxonomy_id])

          if taxonomy.nil?
            @taxon.errors.add(:taxonomy_id, I18n.t('spree.api.invalid_taxonomy_id'))
            invalid_resource!(@taxon) and return
          end

          @taxon.parent_id = taxonomy.root.id unless params[:taxon][:parent_id]

          if @taxon.save
            respond_with(@taxon, status: 201, default_template: :show)
          else
            invalid_resource!(@taxon)
          end
        end

        def update
          authorize! :update, taxon
          if taxon.update(taxon_params)
            respond_with(taxon, status: 200, default_template: :show)
          else
            invalid_resource!(taxon)
          end
        end

        def destroy
          authorize! :destroy, taxon
          taxon.destroy
          respond_with(taxon, status: 204)
        end

        def products
          # Returns the products sorted by their position with the classification
          # Products#index does not do the sorting.
          taxon = Spree::Taxon.find(params[:id])
          @products = taxon.products.ransack(params[:q]).result
          @products = @products.page(params[:page]).per(params[:per_page] || 500)
          render 'spree/api/v1/products/index'
        end

        private

        def taxonomy
          if params[:taxonomy_id].present?
            @taxonomy ||=
              if defined?(SpreeGlobalize)
                Spree::Taxonomy.includes(:translations, taxons: [:translations]).accessible_by(current_ability, :show).find(params[:taxonomy_id])
              else
                Spree::Taxonomy.accessible_by(current_ability, :show).find(params[:taxonomy_id])
              end
          end
        end

        def taxon
          @taxon ||= taxonomy.taxons.accessible_by(current_ability, :show).find(params[:id])
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
