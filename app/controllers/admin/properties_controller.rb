class Admin::PropertiesController < Admin::BaseController
  in_place_edit_for :property, :name
  in_place_edit_for :property, :presentation

  def new
    if request.post? && params[:property]
      @property = Property.new(params[:property])
      if @property.save
        flash[:notice] = 'Option type was successfully created.'
      else  
        logger.error("unable to create new option type: #{@property.inspect}")
        flash[:error] = 'Problem saving new option type.'
        @new_property_error = true
      end
    end
   render :action => :index
  end

  def delete
    property = Property.find(params[:id])
    property.destroy
    flash[:notice] = "Product Property #{property.name} Deleted"
    redirect_to :action => :index
  end

  def new_property_form
    if request.xhr?
      render :partial => 'edit', :locals => { :property => Property.new }
    else
      # not ajax thing
    end
  end
end
