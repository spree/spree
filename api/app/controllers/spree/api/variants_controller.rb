module Spree
  module Api
    class VariantsController < Spree::Api::BaseController
      respond_to :json

      before_filter :product

      def index
        @variants = scope.includes(:option_values).ransack(params[:q]).result.
          page(params[:page]).per(params[:per_page])
        respond_with(@variants)
      end

      def show
        @variant = scope.includes(:option_values).find(params[:id])
        respond_with(@variant)
      end

      def new
      end

      def create
        authorize! :create, Variant
				params[:option_values] = params[:variant][:option_values] if params[:variant] && params[:variant][:option_values]
				variant_params = params[:variant].except(:count_on_hand,:permalink,:images,:cost_price,:is_master,:option_values)
        #@variant = scope.new(params[:variant])
				@variant = Variant.new(variant_params)

        if @variant.save && save_option_values
          respond_with(@variant, :status => 201, :default_template => :show)
        else
          invalid_resource!(@variant)
        end
      end

      def update
        authorize! :update, Variant
        @variant = Variant.find(params[:id])

				params[:option_values] = params[:variant][:option_values] if params[:variant] && params[:variant][:option_values]
				variant_params = params[:variant].except(:count_on_hand,:permalink,:images,:cost_price,:is_master,:option_values)
        
				if @variant.update_attributes(variant_params) && save_option_values
          respond_with(@variant, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def destroy
        authorize! :delete, Variant
        @variant = scope.find(params[:id])
        @variant.destroy
        respond_with(@variant, :status => 204)
      end

      private
				def save_option_values2
					if params[:option_values]
						puts "\n\n#{params[:option_values]}\n\n"
						option_values = params[:option_values]
						@variant.option_values.clear if !@variant.option_values.empty?
						option_values.each_value {|id| @variant.option_values << OptionValue.find(id)}
						@variant.save
					else
						true
					end
				end

				def save_option_values
					if params[:option_values]
						option_values = params[:option_values]
						@variant.option_values.clear if !@variant.option_values.empty?
						option_values.each do |option_value_variant|
							@variant.option_values << OptionValue.find(option_value_variant[:option_value][:id])
						end
						@variant.save
					else
						true
					end		
				end

        def product
          @product ||= Spree::Product.find_by_permalink(params[:product_id]) if params[:product_id]
        end

        def scope
          if @product
            unless current_api_user.has_spree_role?("admin") || params[:show_deleted]
              variants = @product.variants_including_master
            else
              variants = @product.variants_including_master_and_deleted
            end
          else
            variants = Variant.scoped
            if current_api_user.has_spree_role?("admin")
              unless params[:show_deleted]
                variants = Variant.active
              end
            else
              variants = variants.active
            end
          end
          variants
        end
    end
  end
end
