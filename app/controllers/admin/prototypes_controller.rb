class Admin::PrototypesController < Admin::BaseController
  resource_controller
  after_filter :set_properties, :only => [:create, :update]
  
  helper 'admin/product_properties'
  
  def available
    @prototypes = Prototype.all
    render :layout => false
  end
  
  def select
    load_object
  end
  
  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end
    
  # redirect to index (instead of r_c default of show view)
  update.response do |wants| 
    wants.html {redirect_to collection_url}
  end
  
  # redirect to index (instead of r_c default of show view)
  create.response do |wants| 
    wants.html {redirect_to collection_url}
  end
  
  private
  def set_properties
    object.properties.clear
    return unless params[:property]
    params[:property][:id].each do |id|
      object.properties << Property.find(id)
    end
    object.save
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