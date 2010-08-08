class Admin::PrototypesController < Admin::BaseController
  resource_controller
  after_filter :set_habtm_associations, :only => [:create, :update]
  
  helper 'admin/product_properties'
  
  def available
    @prototypes = Prototype.all
    respond_to do |wants|
      wants.html { render :layout => !request.xhr? }
    end
  end
  
  def select
    load_object
    @prototype_properties = @prototype.properties
  end
  
  new_action.response do |wants|
    wants.html {
      render :action => :new, :layout => !request.xhr?
    }
  end
    
  # redirect to index (instead of r_c default of show view)
  update.response do |wants| 
    wants.html {redirect_to collection_url}
  end
  
  # redirect to index (instead of r_c default of show view)
  create.response do |wants| 
    wants.html {redirect_to collection_url}
  end
  
  destroy.success.wants.js { render_js_for_destroy }
  
  private
  def set_habtm_associations
    object.property_ids = params[:property][:id] if params[:property]
    object.option_type_ids = params[:option_type][:id] if params[:option_type]
  end  

  def specified_rights(type)
    rights = []
    key = "#{type}_ids".to_sym     
    params[:permission][key] ||= []
    params[:permission][key].each do |id|
      rights << type.classify.constantize.find(id) 
    end
    rights
  end  
end
