class Admin::ProductsController < Admin::BaseController
  
  def index
    if params[:search]
      @search = SearchCriteria.new(params[:search])
      if @search.valid?
        p = {}
        conditions = build_conditions(p)
        if p.empty? 
          @products = Product.find(:all, :order => "created_at DESC", :page => {:size => 10, :current =>params[:page], :first => 1})          
        else
          @products = Product.find(:all, 
                                   :order => "products.name",
                                   :conditions => [conditions, p],
                                   :include => :variants,
                                   :page => {:size => 10, :current =>params[:page], :first => 1})
        end
      else
        @orders = []
        flash.now[:error] = "Invalid search criteria.  Please check your results."      
      end
    else
      @search = SearchCriteria.new
      @products =  Product.find(:all, :page => {:size => 10, :current =>params[:page], :first => 1})
    end
  end

  def show
    @product = Product.find(params[:id])
  end

  def new
    load_data
    if request.post?
      @product = Product.new(params[:product])
      @product.category = Category.find(params[:category]) unless params[:category].blank?

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

  def edit
    if request.post?
      load_data
      @product = Product.find(params[:id])
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
      
      if @product.update_attributes(params[:product])
        flash[:notice] = 'Product was successfully updated.'
        redirect_to :action => 'edit', :id => @product
      else
        flash.now[:error] = 'Problem updating product.'
      end
    else
      @product = Product.find(params[:id])
      load_data
      @selected_category = @product.category.id if @product.category
    end
  end
  
  def destroy
    flash[:notice] = 'Product was successfully deleted.'
    @product = Product.find(params[:id])
    @product.destroy
    redirect_to :action => 'index'
  end

  #AJAX support method
  def add_option_type
    @product = Product.find(params[:id])
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
    @product = Product.find(params[:id])
    render  :partial => 'option_types', 
            :locals => {:product => @product},
            :layout => false
  end  

  #AJAX method   
  def new_variant
    @product = Product.find(params[:id])
    @variant = Variant.new    
    render  :partial => 'new_variant', 
            :locals => {:product => @product},
            :layout => false    
  end
  
  #AJAX method
  def delete_variant
    @product = Product.find(params[:id])
    Variant.destroy(params[:variant_id])
    flash.now[:notice] = 'Variant successfully removed.'
    render  :partial => 'variants', 
            :locals => {:product => @product},
            :layout => false    
  end

  protected
      def load_data
        @all_categories = Category.find(:all, :order=>"name")  
        @all_categories.unshift Category.new(:name => "<None>")
      end
  
  private
  
      def build_conditions(p)
        c = []
        unless @search.name.blank?
          c << "products.name like :name"
          p.merge! :name => "%" + @search.name + "%"
        end
        unless @search.sku.blank?
          c << "variants.sku like :sku"
          p.merge! :sku => "%" + @search.sku + "%"
        end
        (c.to_sentence :skip_last_comma=>true).gsub(",", " and ")
      end
  
end