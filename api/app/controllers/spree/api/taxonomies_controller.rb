module Spree
  module Api
    class TaxonomiesController < Spree::Api::BaseController
      respond_to :json

      def index
        @taxonomies = Taxonomy.order('name').includes(:root => :children).ransack(params[:q]).result
          .page(params[:page]).per(params[:per_page])
        respond_with(@taxonomies)
      end

      def show
        @taxonomy = Taxonomy.find(params[:id])
        respond_with(@taxonomy)
      end

      def create
        authorize! :create, Taxonomy
        @taxonomy = Taxonomy.new(params[:taxonomy])
        if @taxonomy.save
          respond_with(@taxonomy, :status => 201, :default_template => :show)
        else
          invalid_resource!(@taxonomy)
        end
      end

      def update
        authorize! :update, Taxonomy
        if taxonomy.update_attributes(params[:taxonomy])
          respond_with(taxonomy, :status => 200, :default_template => :show)
        else
          invalid_resource!(taxonomy)
        end
      end

      def destroy
        authorize! :delete, Taxonomy
        taxonomy.destroy
        respond_with(taxonomy, :status => 204)
      end

      private

      def taxonomy
        @taxonomy ||= Taxonomy.find(params[:id])
      end

    end
  end
end
