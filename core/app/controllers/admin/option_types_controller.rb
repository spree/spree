class Admin::OptionTypesController < Admin::BaseController
  resource_controller

  before_filter :load_object, :only => [:selected, :available, :remove]
  belongs_to :product

  def available
    set_available_option_types
    render :layout => false
  end

  def selected
    @option_types = @product.option_types
  end

  def remove
    @product.option_types.delete(@option_type)
    @product.save
    flash.notice = I18n.t("notice_messages.option_type_removed")
    redirect_to selected_admin_product_option_types_url(@product)
  end

  new_action.response do |wants|
    wants.html {render :action => :new, :layout => !request.xhr?}
  end

  # redirect to index (instead of r_c default of show view)
  create.response do |wants|
    wants.html {redirect_to edit_object_url}
  end

  # redirect to index (instead of r_c default of show view)
  update.response do |wants|
    wants.html {redirect_to collection_url}
  end

  destroy.success.wants.js { render_js_for_destroy }

  # AJAX method for selecting an existing option type and associating with the current product
  def select
    @product = Product.find_by_param!(params[:product_id])
    product_option_type = ProductOptionType.new(:product => @product, :option_type => OptionType.find(params[:id]))
    product_option_type.save
    @product.reload
    @option_types = @product.option_types
    set_available_option_types
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
