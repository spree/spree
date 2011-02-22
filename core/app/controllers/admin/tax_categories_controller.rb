class Admin::TaxCategoriesController < Admin::BaseController

  before_filter :load_tax_category, :only => [:edit, :update, :destroy]
  before_filter :set_new_collection_url

  def set_new_collection_url
    @new_collection_url = admin_tax_categories_path
  end

  def index
    @tax_categories = TaxCategory.all
  end

  def new
    @tax_category = TaxCategory.new
  end

  def create
    @tax_category = TaxCategory.new(params[:tax_category])
    if @tax_category.save
      flash.notice = "Successfully created!"
      redirect_to admin_tax_categories_path
    else
      render :action => 'new'
    end
  end

  def edit
    respond_to do |format|
      format.html
    end
  end

  def update
    respond_to do |format|
      if @tax_category.update_attributes(params[:tax_category])
        flash.notice = "Successfully updated!"
        format.html { redirect_to admin_tax_categories_path }
      else
        format.html { render :action => 'edit' }
      end
    end
  end

  def destroy #FIXME write test for this case
    @tax_category.destroy
    respond_to do |format|
      format.js { redirect_to admin_tax_categories_path }
    end
  end

  private

  def load_tax_category
    @tax_category = TaxCategory.find(params[:id])
  end

end
