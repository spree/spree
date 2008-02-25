class Admin::OptionTypesController < Admin::BaseController
  def select
    @product = Product.find(params[:id])
    @option_types = OptionType.find(:all)
    selected_option_types = []
    @product.selected_options.each do |so| 
      selected_option_types << so.option_type
    end
    @option_types.delete_if {|ot| selected_option_types.include? ot}
    
    render :layout => false
  end  
  
  def index
    @option_types = OptionType.find(:all)
  end
  
  def new
    if request.post?
      @option_type = OptionType.new(params['option_type']) 
      if @option_type.save
        flash[:notice] = 'Option type was successfully created.'
        redirect_to :action => 'index'    
      else  
        logger.error("unable to create new option type: #{@option_type.inspect}")
        flash[:error] = 'Problem saving new option type.'
        render :action => 'new'
      end
    else
      @option_type = OptionType.new 
    end
  end
  
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
  
  def delete
    Option.delete(params[:id])
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
end