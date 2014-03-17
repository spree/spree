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
        option_type_attributes = params[:product].delete(:option_types) || []
        set_up_shipping_category

        @product = Product.new(params[:product])
        begin
          if @product.save
            variants_attributes.each do |variant_attribute|
              variant = @product.variants.new
              variant.update_attributes(variant_attribute)
            end

            option_type_attributes.each do |name|
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
        authorize! :update, Product

        variants_attributes = params[:product].delete(:variants_attributes) || []
        option_type_attributes = params[:product].delete(:option_types) || []
        set_up_shipping_category

        @product = find_product(params[:id])
        if @product.update_attributes(params[:product])
          variants_attributes.each do |variant_attribute|
            # update the variant if the id is present in the payload
            if variant_attribute['id'].present?
              @product.variants.find(variant_attribute['id'].to_i).update_attributes(variant_attribute)
            else
              variant = @product.variants.new
              variant.update_attributes(variant_attribute)
            end
          end

          option_type_attributes.each do |name|
            option_type = OptionType.where(name: name).first_or_initialize do |option_type|
              option_type.presentation = name
              option_type.save!
            end

            @product.option_types << option_type unless @product.option_types.include?(option_type)
          end

          respond_with(@product, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def destroy
        authorize! :delete, Product
        @product = find_product(params[:id])
        @product.destroy
        respond_with(@product, :status => 204)
      end

      private
        def set_up_shipping_category
          if shipping_category = params[:product].delete(:shipping_category)
            id = ShippingCategory.find_or_create_by_name(shipping_category).id
            params[:product][:shipping_category_id] = id
          end
        end
    end
  end
end
