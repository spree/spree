module Spree
  module Api
    class TaxonsController < Spree::Api::BaseController
      respond_to :json

      def index
        if taxonomy
          @taxons = taxonomy.root.children
        else
          if params[:ids]
            @taxons = Taxon.accessible_by(current_ability, :read).where(:id => params[:ids].split(","))
          else
            @taxons = Taxon.accessible_by(current_ability, :read).order(:taxonomy_id, :lft).ransack(params[:q]).result
          end
        end

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

      def create
        authorize! :create, Taxon
        @taxon = Taxon.new(params[:taxon])
        @taxon.taxonomy_id = params[:taxonomy_id]
        taxonomy = Taxonomy.find_by_id(params[:taxonomy_id])

        if taxonomy.nil?
          @taxon.errors[:taxonomy_id] = I18n.t(:invalid_taxonomy_id, :scope => 'spree.api')
          invalid_resource!(@taxon) and return
        end

        @taxon.parent_id = taxonomy.root.id unless params[:taxon][:parent_id]

        if @taxon.save
          respond_with(@taxon, :status => 201, :default_template => :show)
        else
          invalid_resource!(@taxon)
        end
      end

      def update
        authorize! :update, Taxon
        if taxon.update_attributes(params[:taxon])
          respond_with(taxon, :status => 200, :default_template => :show)
        else
          invalid_resource!(taxon)
        end
      end

      def destroy
        authorize! :delete, Taxon
        taxon.destroy
        respond_with(taxon, :status => 204)
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
