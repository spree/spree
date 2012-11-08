module Spree
  module Api
    module V1
      class TaxonomiesController < Spree::Api::V1::BaseController
        def index
          @taxonomies = Taxonomy.order('name').includes(:root => :children).ransack(params[:q]).result
            .page(params[:page]).per(params[:per_page])
        end

        def show
          @taxonomy = Taxonomy.find(params[:id])
        end

        def create
          authorize! :create, Taxonomy
          @taxonomy = Taxonomy.new(params[:taxonomy])
          if @taxonomy.save
            render :show, :status => 201
          else
            invalid_resource!(@taxonomy)
          end
        end

        def update
          authorize! :update, Taxonomy
          if taxonomy.update_attributes(params[:taxonomy])
            render :show, :status => 200
          else
            invalid_resource!(taxonomy)
          end
        end

        def destroy
          authorize! :delete, Taxonomy
          taxonomy.destroy
          render :text => nil, :status => 204
        end

        private

        def taxonomy
          @taxonomy ||= Taxonomy.find(params[:id])
        end

      end
    end
  end
end
