class Admin::OptionTypesController < Admin::BaseController
  resource_controller
  belongs_to :product

  index.response do |wants|    
    wants.html {render :layout => 'admin.html.erb'}
    wants.selected {render :layout => 'admin.html.erb'}
    wants.available do
      set_available_option_types
      render :layout => false
    end
    #wants.available {render :layout => false}
  end

  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end
    
  # redirect to index (instead of r_c default of show view)
  create.response do |wants| 
    wants.html {redirect_to collection_url}
  end

  # redirect to index (instead of r_c default of show view)
  update.response do |wants| 
    wants.html {redirect_to collection_url}
  end

  # AJAX method for selecting an existing option type and associating with the current product
  def select
    @product = Product.find_by_param!(params[:product_id])
    product_option_type = ProductOptionType.new(:product => @product, :option_type => OptionType.find(params[:id]))
    product_option_type.save
    @product.reload
    @option_types = @product.option_types
    set_available_option_types
    render :template => "admin/option_types/index.selected.erb", :layout => false
  end

=begin
  def edit
    @option_type = OptionType.find(params[:id])
    if request.post?
      success = @option_type.update_attributes(params[:option_type])
      if success and params[:option_value]
        option_value = OptionValue.new(params[:option_value])
        @option_type.option_values << option_value
        success = @option_type.save
      end
      flash[:notice] = 'Option type was successfully updated.' if success
      flash[:error] = "Problem updating option type." if not success
      redirect_to :action => 'edit', :id => @option_type
    end
  end
  
  def destroy
    OptionType.destroy(params[:id])
    redirect_to :action => 'index'
  end  

  #AJAX support method
  def new_option_value
    @option_type = OptionType.find(params[:id])
    render  :partial => 'new_option_value', 
            :locals => {:option_type => @option_type},
            :layout => false
  end  

  #AJAX support method
  def delete_option_value
    OptionValue.delete(params[:option_value_id])
    @option_type = OptionType.find(params[:id])
    render  :partial => 'option_values', 
            :locals => {:option_type => @option_type},
            :layout => false
  end    
=end  

  private 
  
    def set_available_option_types
      @available_option_types = OptionType.all
      selected_option_types = []
      @product.options.each do |option| 
        selected_option_types << option.option_type
      end
      @available_option_types.delete_if {|ot| selected_option_types.include? ot}
    end
end
