class Admin::OptionTypesController < Admin::BaseController
  resource_controller
  
  before_filter :load_object, :only => [:selected, :available]
  belongs_to :product
  
  def available
    set_available_option_types
    render :layout => false
  end
  
  def selected 
    @option_types = @product.option_types
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
    render :template => "admin/option_types/selected.html.erb", :layout => false
  end 

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
