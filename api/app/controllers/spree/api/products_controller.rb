module Spree
  module Api
    class ProductsController < Spree::Api::BaseController
      respond_to :json

      def index
        if params[:ids]
          @products = product_scope.where(:id => params[:ids].split(","))
        else
          @products = product_scope.ransack(params[:q]).result
        end

        @products = @products.page(params[:page]).per(params[:per_page])

        respond_with(@products)
      end

      def show
        @product = find_product(params[:id])
        respond_with(@product)
      end

      def new
      end

      def create
        authorize! :create, Product
        params[:product][:available_on] ||= Time.now

        variants_attributes = params[:product].delete(:variants_attributes) || []

        @product = Product.new(params[:product])
        begin
          if @product.save
            variants_attributes.each do |variant_attribute|
              variant = @product.variants.new
              variant.update_attributes(variant_attribute)
            end

            params[:product].fetch(:option_types, []).each do |name|
              option_type = OptionType.where(name: name).first_or_initialize do |option_type|
                option_type.presentation = name
                option_type.save!
              end

              @product.option_types << option_type
            end

            respond_with(@product, :status => 201, :default_template => :show)
          else
            invalid_resource!(@product)
          end
        rescue ActiveRecord::RecordNotUnique
          @product.permalink = nil
          retry
        end
      end

      def update
        authorize! :update, Product
        @product = find_product(params[:id])
        if @product.update_attributes(params[:product])
          respond_with(@product, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def destroy
        authorize! :delete, Product
        @product = find_product(params[:id])
        @product.update_attribute(:deleted_at, Time.now)
        @product.variants_including_master.update_all(:deleted_at => Time.now)
        respond_with(@product, :status => 204)
      end
    end
  end
end
