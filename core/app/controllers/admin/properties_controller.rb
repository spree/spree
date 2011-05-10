class Admin::PropertiesController < Admin::ResourceController

  # Looks like this action is unused
  def filtered
    @properties = Property.where('lower(name) LIKE ?', "%#{params[:q].mb_chars.downcase}%").order(:name)
    respond_with(@properties) do |format| 
      format.html { render :template => "admin/properties/filtered.html.erb", :layout => false } 
    end
  end

end
