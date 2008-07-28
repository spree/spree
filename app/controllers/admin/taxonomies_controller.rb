class Admin::TaxonomiesController < Admin::BaseController
  def index
    find_taxonomies
  end

  def list
    find_taxonomies
    render :partial => 'list'
  end

  def edit
    @taxonomy = find_taxonomy
    render :partial => 'edit'
  end

  def new
    render :partial => 'new'
  end

  def delete
    taxonomy = find_taxonomy
    taxonomy.destroy
    if request.xhr?
      render :partial => 'success', :status => 201
    else
      redirect_to :index
    end
  end

  def update_taxonomy
    if request.post? && params[:taxonomy]
      taxonomy = find_taxonomy

      ## create or update root node of taxonomic tree
      root_taxon = nil
      if taxonomy.new_record?
        root_taxon = Taxon.new(params[:taxonomy])
        root_taxon.taxonomy = taxonomy
      else
        root_taxon = taxonomy.root
        root_taxon.update_attributes(params[:taxonomy])
      end

      taxonomy.update_attributes(params[:taxonomy])
      if taxonomy.save && root_taxon.save
        if request.xhr?
          render :partial => 'success', :status => 201
        else
          redirect_to :index
        end
      else
        if request.xhr?
          render :partial => 'edit'
        else
          redirect_to :index
        end
      end
    else
      taxonomy = Taxonomy.new(params[:taxonomy])
      render :partial => 'new'
    end
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

  def manage_products
    @taxon = Taxon.find(params[:id])
    render :partial => 'manage_products'
  end

  def assign_products
    @taxon = Taxon.find(params[:id])
    product_ids = params[:product_ids]
    logger.debug("product ids: #{product_ids.inspect}")
    @taxon.products = []
    
    product_ids.each do |p|
      begin
        @taxon.products << Product.find(p)
      rescue ActiveRecord::RecordNotFound 
        # XXX fail silently for now, but proper error handling
        # should be put in place here
      end
    end
    @taxon.save
    render :partial => 'manage_products'
  end

  private
  def find_taxon
    taxon = Taxon.find(params[:id]) if params[:id]
    taxon = Taxon.new(params[:taxon]) unless taxon
    taxon
  end

  def find_taxonomy
    taxonomy = nil
    if (params[:id])
      begin
        taxonomy = Taxonomy.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        ## invalid record ID apparently
        ## XXX fail silently for now
      end
    else
      taxonomy = Taxonomy.new(params[:taxonomy])
    end
    taxonomy
  end

  def find_taxonomies
    @taxonomies = Taxonomy.find(:all, :page => {:size => 10, :current =>params[:page], :first => 1})
  end
 
end
