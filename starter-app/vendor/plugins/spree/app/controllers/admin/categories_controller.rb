class Admin::CategoriesController < Admin::BaseController
    
  def index
    list
    render :action => 'list'
  end

  def list
    if params[:id]
      @categories = Category.find(:all, :conditions=>["parent_id = ?", params[:id]], :page => {:size => 10, :current =>params[:page], :first => 1})
      @parent_category = Category.find(params[:id])
    else
      @categories = Category.find(:all, :conditions=>["parent_id IS NULL"], :page => {:size => 10, :current =>params[:page], :first => 1})
    end
  end

  def new
    load_data
    if request.post?
      @category = Category.new(params[:category])
      @category.tax_treatments = TaxTreatment.find(params[:tax_treatments]) if params[:tax_treatments]
      if @category.save
        flash[:notice] = 'Category was successfully created.'
        redirect_to :action => 'list'
      end
    else
      @category = Category.new
      #@category.parent = @all_categories.first
    end
  end

  def edit
    load_data
    @category = Category.find(params[:id])
  end

  def update
    @category = Category.find(params[:id])
    # clear out previous tax treatments since deselecting them will not communicated via POST
    @category.tax_treatments.clear
    @category.tax_treatments = TaxTreatment.find(params[:tax_treatments]) if params[:tax_treatments]
    @category.save
      
    if @category.update_attributes(params[:category])
      flash[:notice] = 'Category was successfully updated.'
      redirect_to :action => 'index'
    else
      render :action => 'edit'
    end
  end

  def destroy
    category=Category.find(params[:id])
    category.destroy
    flash[:notice] = "Category was successfully destroyed."
    redirect_to :action => 'list'
  end

  # AJAX method to show tax treatments based on change in parent category 
  def tax_treatments
    category = Category.find_or_initialize_by_id(params[:category_id])
    if params[:parent_id].blank?
      category.parent = nil
    else
      category.parent = Category.find(params[:parent_id])      
    end

    @all_tax_treatments = TaxTreatment.find(:all)

    render  :partial => 'shared/tax_treatments', 
            :locals => {:tax_treatments => @all_tax_treatments, :selected_treatments => category.tax_treatments},
            :layout => false
  end

  private
  
      def load_data
        @all_categories = Category.find(:all, :order=>"name") 
        @all_categories.unshift Category.new(:name => "<None>")
        @all_tax_treatments = TaxTreatment.find(:all)
      end
end       
       