class Admin::ProductGroupsController < Admin::BaseController
  resource_controller
  
  create.response do |wants| 
    wants.html { redirect_to edit_object_path }
  end
  update.response do |wants| 
    wants.html { redirect_to edit_object_path }
    wants.js { render :action => 'update', :layout => false}
  end

  def preview
    @product_group = ProductGroup.new(params[:product_group])
    @product_group.name = "for_preview"
    render :partial => 'preview', :layout => false
  end

  
  private

    # Consolidate argument arrays for nested product_scope attributes
    # Necessary for product scopes with multiple arguments
    def object_params
      if params["product_group"] and params["product_group"]["product_scopes_attributes"].is_a?(Array)
        params["product_group"]["product_scopes_attributes"] = params["product_group"]["product_scopes_attributes"].group_by {|a| a["id"]}.map do |scope_id, attrs| 
          a = { "id" => scope_id, "arguments" => attrs.map{|a| a["arguments"] }.flatten }
          if name = attrs.first["name"]
            a["name"] = name
          end
          a
        end
      end
      params["product_group"]
    end

    def collection
      @search = ProductGroup.searchlogic(params[:search])

      @collection = @search.do_search.paginate(
        :per_page => Spree::Config[:per_page],
        :page     => params[:page]
      )
    end

end
