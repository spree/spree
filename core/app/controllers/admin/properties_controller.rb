class Admin::PropertiesController < Admin::BaseController
  resource_controller
  
  before_filter :load_object, :only => :filtered
  belongs_to :product
  
  def filtered
    @properties = Property.where('lower(name) LIKE ?', "%#{params[:q].downcase}%").order(:name)
    render :template => "admin/properties/filtered.html.erb", :layout => false
  end
  
  new_action.response do |wants|
    wants.html {render :action => :new, :layout => !request.xhr? }
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
end
