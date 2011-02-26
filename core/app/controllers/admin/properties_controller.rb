class Admin::PropertiesController < Admin::ResourceController

  # Looks like this action is unused
  def filtered
    @properties = Property.where('lower(name) LIKE ?', "%#{params[:q].downcase}%").order(:name)
    render :template => "admin/properties/filtered.html.erb", :layout => false
  end

end
