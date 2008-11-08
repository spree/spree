class Admin::VariantsController < Admin::BaseController
  resource_controller
  belongs_to :product
  before_filter :load_data, :only => [:index, :edit, :new]
  
  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

  create.before do 
    option_values = params[:new_variant]
    option_values.each_value {|id| @object.option_values << OptionValue.find(id)}
    @object.save
  end
  
  # redirect to index (instead of r_c default of show view)
  create.response do |wants| 
    wants.html {redirect_to collection_url}
  end

  # redirect to index (instead of r_c default of show view)
  update.response do |wants| 
    wants.html {redirect_to collection_url}
  end
  
  private
  def load_data
    # this allows extensions to provide their own additional columns in the index and edit views
    @additional_fields = Variant.column_names - ["id", "price", "sku", "product_id"]
  end
  
end
