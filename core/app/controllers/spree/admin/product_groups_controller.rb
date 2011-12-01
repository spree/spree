module Spree
  module Admin
    class ProductGroupsController < ResourceController
      before_filter :patch_params, :only => [:update]
  
      def preview
        @product_group = ProductGroup.new(params[:product_group])
        @product_group.name = "for_preview"
        respond_with(@product_group) { |format| format.html { render :partial => 'preview', :layout => false } }
      end

      protected

        def find_resource
          ProductGroup.find_by_permalink!(params[:id])
        end
     
        def location_after_save
          edit_admin_product_group_path(@product_group)
        end

        def collection
          params[:search] ||= {}
          params[:search][:meta_sort] ||= "name.asc"
          @search = super.metasearch(params[:search])
          @collection = @search.relation.page(params[:page]).per(Spree::Config[:admin_pgroup_per_page])
        end
    
      private

        # Consolidate argument arrays for nested product_scope attributes
        # Necessary for product scopes with multiple arguments
        def patch_params
          if params["product_group"] and params["product_group"]["product_scopes_attributes"].is_a?(Array)
            params["product_group"]["product_scopes_attributes"] = params["product_group"]["product_scopes_attributes"].group_by {|a| a["id"]}.map do |scope_id, attrs|
              a = { "id" => scope_id, "arguments" => attrs.map{|a| a["arguments"] }.flatten }
              if name = attrs.first["name"]
                a["name"] = name
              end
              a
            end
          end
        end



    end
  end
end
