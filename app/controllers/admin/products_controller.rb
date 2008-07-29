class Admin::ProductsController < Admin::BaseController
  resource_controller
  before_filter :load_data

  def new
    if request.post?
      @product = Product.new(params[:product])

      @sku = params[:sku]
      @on_hand = params[:on_hand]

      if @product.save
        # create a sku (if one has been supplied)
        @product.variants.first.update_attributes(:sku => @sku) if @sku
        InventoryUnit.create_on_hand(@product.variants.first, @on_hand.to_i) if @on_hand
        flash[:notice] = 'Product was successfully created.'
        redirect_to :action => :edit, :id => @product      
      else
        flash.now[:error] = "Problem saving new product #{@product}"
      end
    else
      @product = Product.new
    end
  end
=begin
  def edit
    if request.post?
      load_data
      @product = Product.find_by_param(params[:id])
      category_id = params[:category]
      @product.category = (category_id.blank? ? nil : Category.find(params[:category]))

      if params[:variant]
        @product.variants.update params[:variant].keys, params[:variant].values
      end
      
      if params[:new_variant]
        variant = Variant.new(:product => @product)
        option_values = params[:new_variant]
        option_values.each_value {|id| variant.option_values << OptionValue.find(id)}
        @product.variants << variant
        @product.save
      end

      if params[:image]
        @product.images << Image.new(params[:image])
        @product.save
      end
      
      if params[:property_value]
        @product.property_values.update params[:property_value].keys, params[:property_value].values
      end

      if params[:add_property_value]
        logger.debug("ADD PRODUCT PROPERTY VALUE: #{params.inspect}")
        params[:add_property_value].keys.each do |property_id|
          next if params[:add_property_value][property_id][:value].empty?
          PropertyValue.create( :product_id => @product.id,
                                :property_id => property_id,
                                :value => params[:add_property_value][property_id][:value] );
        end
      end

#      @product.tax_treatments = TaxTreatment.find(params[:tax_treatments]) if params[:tax_treatments]
#      @product.save

      if @product.update_attributes(params[:product])
        flash[:notice] = 'Product was successfully updated.'
        redirect_to :action => 'edit', :id => @product
      else
        flash.now[:error] = 'Problem updating product.'
      end
    else
      @product = Product.find_by_param(params[:id])
      load_data
      @selected_category = @product.category.id if @product.category
    end
  end
  def destroy
    flash[:notice] = 'Product was successfully deleted.'
    @product = Product.find_by_param(params[:id])
    @product.destroy
    redirect_to :action => 'index'
  end
=end
  #AJAX support method
  def add_option_type
    @product = Product.find_by_param(params[:id])
    pot = ProductOptionType.new(:product => @product, :option_type => OptionType.find(params[:option_type_id]))
    @product.selected_options << pot
    @product.save
    render  :partial => 'option_types', 
            :locals => {:product => @product},
            :layout => false
  end  

  #AJAX support method
  def remove_option_type
    ProductOptionType.delete(params[:product_option_type_id])
    @product = Product.find_by_param(params[:id])
    render  :partial => 'option_types', 
            :locals => {:product => @product},
            :layout => false
  end  

  #AJAX method   
  def new_variant
    @product = Product.find_by_param(params[:id])
    @variant = Variant.new    
    render  :partial => 'new_variant', 
            :locals => {:product => @product},
            :layout => false    
  end
  
  #AJAX method
  def delete_variant
    @product = Product.find_by_param(params[:id])
    Variant.destroy(params[:variant_id])
    flash.now[:notice] = 'Variant successfully removed.'
    render  :partial => 'variants', 
            :locals => {:product => @product},
            :layout => false    
  end

  #AJAX method
  def edit_property_value
    @property_value = PropertyValue.find(params[:id])
    if params[:cancel]
      render :text => @property_value.value
    else
      render ({ :partial => 'edit_property_value',
                :locals => { :property_value => @property_value } })
    end
  end


  #AJAX method
  def remove_property_value
    @property_value = PropertyValue.find(params[:id])
    @product = @property_value.product
    @property_value.destroy
    render :partial => 'properties', :locals => { :product => @product }
  end

  #AJAX method
  def add_property_value
    @product = Product.find_by_param(params[:id])
    @property_value = PropertyValue.new
    render :partial => 'add_property_value', :locals => { :product => @product }
  end

  #AJAX method
  def add_property_value_view
    if !['all', 'prototype'].include?(params[:view])
      flash.now[:error] = 'invalid property value view'
      render :nothing => true
      return
    end
    @product = Product.find_by_param(params[:id])
    render({ :partial => "add_property_value_view_#{params[:view]}",
             :locals => { :product => @product } })
  end

  #AJAX method
  def add_property_value_view_prototype_list
    @product = Product.find_by_param(params[:id])
    @prototype = Prototype.find(params[:prototype_id])
    render({ :partial => "add_property_value_view_prototype_list",
             :locals => { :product => @product, :prototype => @prototype } })
  end

  private
    def load_data
      @tax_categories = TaxCategory.find(:all, :order=>"name")  
    end

    def collection
      @name = params[:name] || ""
      @sku = params[:sku] || ""
      @collection ||= end_of_association_chain.by_name(@name).by_sku(@sku).find(:all, :order => :name, :page => {:start => 1, :size => 10, :current => params[:page]})
    end
    
    def object      
      @object ||= Product.find_by_param!(params[:id])
    end    
end
