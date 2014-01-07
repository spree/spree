module Spree
  module Api
    class ProductsController < Spree::Api::BaseController

      def index
        if params[:ids]
          @products = product_scope.where(:id => params[:ids].split(","))
        else
          @products = product_scope.ransack(params[:q]).result
        end

        @products = @products.page(params[:page]).per(params[:per_page])
      end

      def show
        @product = find_product(params[:id])
        expires_in 3.minutes
        respond_with(@product)
      end

      def new
      end

      def create
        authorize! :create, Product
        params[:product][:available_on] ||= Time.now
        
        begin
          @product = Product.new(product_without_variants_params)
          if @product.save
            variants_params.each do |variant_attribute|
              @product.variants.create variant_attribute.merge(product: @product)
            end

            option_types_params.each do |name|
              option_type = OptionType.where(name: name).first_or_initialize do |option_type|
                option_type.presentation = name
                option_type.save!
              end

              @product.option_types << option_type unless @product.option_types.include?(option_type)
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
        @product = find_product(params[:id])
        authorize! :update, @product
      
        if @product.update_attributes(product_params)
          respond_with(@product, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def destroy
        @product = find_product(params[:id])
        authorize! :destroy, @product
        @product.update_attribute(:deleted_at, Time.now)
        @product.variants_including_master.update_all(:deleted_at => Time.now)
        respond_with(@product, :status => 204)
      end

      private
        def product_params
          product_params = params.require(:product).permit(permitted_product_attributes)
          if product_params[:taxon_ids].present?
            product_params[:taxon_ids] = product_params[:taxon_ids].split(',')
          end
          product_params
        end

        def product_without_variants_params
          h = Hash[product_params].with_indifferent_access
          h.delete(:variants_attributes)
          h.delete(:option_types)
          h
        end

        def variants_params
          product_params.fetch(:variants_attributes, {})
        end

        def option_types_params
          product_params.fetch(:option_types, [])
        end
    end
  end
end
