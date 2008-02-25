class Admin::ProductsController < Admin::BaseController
  require_role "admin"
  
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
                                   :joins => "as products inner join skus on products.id = skus.stockable_id ", #and s.stockable_type = 'Product'",
                                   :conditions => [conditions, p],
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

  #@products = searcher_find(:product, Product).
  end

  def show
    @product = Product.find(params[:id])
  end

  def new
    load_data
    if request.post?
      @product = Product.new(params[:product])
      @product.sku = Sku.new("number" => params[:sku][:number])
      @product.category = Category.find(params[:category]) unless params[:category].blank?

      if @product.save
        #can't create tagging associations until product is saved
        unless params[:tags].blank?
          begin
            @product.tag_with params[:tags]
          rescue Tag::Error
            flash.now[:error] = "Tag cannot contain special characters."
            return
          end
        end        
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
      

      @product.sku.number = params[:sku][:number]
      @product.sku.save
      
      if params[:variation]
        @variation = Variation.new(params[:variation])
        unless @variation.valid?
          flash[:error] = "Problem saving variation"
          redirect_to :action => "edit", :id => @product and return
        end
        @product.variations << @variation if @variation
      end
      
      # need to clear this every time in case user removes tags (those won't show up in the post)
      @product.taggings.clear

      unless params[:tags].blank?
        begin
          @product.tag_with params[:tags]
        rescue Tag::Error
          flash.now[:error] = "Tag cannot contain special characters."
          return
        end
      end
      
      if params[:new_variation]
        v = Variation.new
        params[:new_variation].each do |key, value|
          v.option_values << OptionValue.find(value)
        end
        v.save
        @product.variations << v
        @product.save
      end
      
      if params[:image]
        @product.images << Image.new(params[:image])
      end
      
      @product.tax_treatments = TaxTreatment.find(params[:tax_treatments]) if params[:tax_treatments]
      @product.save
      
      #if @product.sku.save && @product.update_attributes(params[:product])
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

  # AJAX method to show tax treatments based on change in category
  def tax_treatments
    product = Product.find_or_initialize_by_id(params[:id])
    if params[:category_id].blank?
      product.category = nil
    else
      product.category = Category.find(params[:category_id])
    end
    @all_tax_treatments = TaxTreatment.find(:all)
    render  :partial => 'shared/tax_treatments', 
            :locals => {:tax_treatments => @all_tax_treatments, :selected_treatments => product.tax_treatments},
            :layout => false
  end
    
  #AJAX method   
  def new_variation
    @product = Product.find(params[:id])
    @variation = Variation.new    
    render  :partial => 'new_variation', 
            :locals => {:product => @product},
            :layout => false    
  end
  
  #AJAX method
  def delete_variation
    @product = Product.find(params[:id])
    Variation.destroy(params[:variation_id])
    flash.now[:notice] = 'Variation successfully removed.'
    render  :partial => 'variations', 
            :locals => {:product => @product},
            :layout => false    
  end

  protected
      def load_data
        @all_categories = Category.find(:all, :order=>"name")  
        @all_categories.unshift Category.new(:name => "<None>")
        @all_tax_treatments = TaxTreatment.find(:all, :order=>"name")
      end
  
  private
  
      def build_conditions(p)
        c = []
        unless @search.name.blank?
          c << "products.name like :name"
          p.merge! :name => "%" + @search.name + "%"
        end
        unless @search.sku.blank?
          c << "skus.number like :sku"
          p.merge! :sku => "%" + @search.sku + "%"
        end
        (c.to_sentence :skip_last_comma=>true).gsub(",", " and ")
      end
  
end