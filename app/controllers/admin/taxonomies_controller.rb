class Admin::TaxonomiesController < Admin::BaseController
  def index
    list
    render :action => 'list'
  end

  def list
    @taxonomies = Taxonomy.find(:all, :page => {:size => 10, :current =>params[:page], :first => 1})
  end

  def edit
    @taxonomy = Taxonomy.find(params[:id])
    render :partial => 'edit'
  end

  def new_taxon
    @taxon = Taxon.new(params[:new_taxon])
    render :partial => 'edit_taxon'
  end

  def update_taxon
    if request.post? && params[:taxon]
      @taxon = find_taxon
      @taxon.update_attributes(params[:taxon])
      if @taxon.save
        if request.xhr?
          render :partial => 'success', :status => 201
        else
          redirect_to :index
        end
      else
        if request.xhr?
          render :partial => 'edit_taxon'
        else
          redirect_to :index
        end
      end
    else
      @taxon = Taxon.new(params[:new_taxon])
      render :partial => 'edit_taxon'
    end
  end

  def delete_taxon
    taxon = Taxon.find(params[:id])
    @taxonomy = Taxonomy.find(taxon.taxonomy_id)
    taxon.destroy
    render :partial => 'edit'
  end

  def move_taxon
    taxon = Taxon.find(params[:id])
    orig_parent = taxon.parent
    new_parent = Taxon.find(params[:parent_id])
    taxon.move_to(new_parent)
    render :text => "moved #{taxon.id} from #{orig_parent.id} to #{taxon.parent_id}", 
           :status => 201
  end

  private
  def find_taxon
    taxon = Taxon.find(params[:id]) if params[:id]
    taxon = Taxon.new(params[:taxon]) unless taxon
    taxon
  end
end
