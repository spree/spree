class Admin::TaxonomiesController < Admin::BaseController
  resource_controller

  before_filter :load_taxonomy, :only => [:edit, :update]

  def index
    respond_to do |format|
      @taxonomies = Taxonomy.order('name')
      format.html
    end
  end

  def new
    @taxonomy = Taxonomy.new
    respond_to do |format|
      format.html
      format.js do
        render :partial => 'edit.html.erb'
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
    end
  end

  def update
    if @taxonomy.update_attributes(params[:taxonomy])
      flash.notice = 'Successfully updated!'
      redirect_to admin_taxonomies_path
    else
      render :action => 'edit'
    end
  end

  def create
    @taxonomy = Taxonomy.new(params[:taxonomy])
    if @taxonomy.save
      flash.notice = 'Successfully created!'
      redirect_to admin_taxonomies_path
    else
      render :action => 'new'
    end
  end

  def get_children
    @taxons = Taxon.find(params[:parent_id]).children
  end

  private

  def load_taxonomy
    @taxonomy = Taxonomy.find(params[:id])
  end
end
