class Admin::TaxonsController < Admin::BaseController
  resource_controller
  
  before_filter :load_object, :only => [:selected, :available, :remove]
  belongs_to :product
  
  create.wants.js {render :text => @taxon.to_json()}
  update.wants.js {render :text => @taxon.name}
  destroy.wants.js {render :text => ""}
  
  create.before do 
    @taxon.taxonomy_id = params[:taxonomy_id]
    @taxon.position = Taxon.find(@taxon.parent_id).children.length + 1
  end
  
  update.before do
    #taxon being moved to new parent
    unless @taxon.parent_id == params[:taxon][:parent_id]
      reposition_taxons(Taxon.find_all_by_parent_id(@taxon.parent_id))

      @taxon.position = Taxon.find(params[:taxon][:parent_id]).children.length + 1
    end if params[:taxon].include? "parent_id"
    
    #taxon being moved up or down
    unless @taxon.position == params[:taxon][:position]
      taxons = Taxon.find_all_by_parent_id(@taxon.parent_id)
      taxons.slice! taxons.index(@taxon)
      
      #taxon getting forced out of the way
      taxon = Taxon.find_by_position_and_parent_id(params[:taxon][:position], @taxon.parent_id)
      
      if @taxon.position < params[:taxon][:position].to_f
        taxon.position += -1
      elsif @taxon.position > params[:taxon][:position].to_f
        taxon.position += 1
      end
      
      taxon.save!

    end if params[:taxon].include? "position"
  end
  
  destroy.after do
    reposition_taxons(Taxon.find_all_by_taxonomy_id(@taxon.taxonomy_id))

  end
    
  def selected 
    @taxons = @product.taxons
  end
  
  def available
    if params[:q].blank?
      @available_taxons = []
    else
      @available_taxons = Taxon.find(:all, :conditions => ['lower(name) LIKE ?', "%#{params[:q].downcase}%"])
    end
    @available_taxons.delete_if { |taxon| @product.taxons.include?(taxon) }
    respond_to do |format|
      format.html
      format.js {render :layout => false}
    end

  end
  
  def remove
    @product.taxons.delete(@taxon)
    @product.save
    @taxons = @product.taxons
    render :layout => false
  end  
  
  def select
    @product = Product.find_by_param!(params[:product_id])
    taxon = Taxon.find(params[:id])
    @product.taxons << taxon
    @product.save
    @taxons = @product.taxons
    render :layout => false
  end
  
  private 
  def reposition_taxons(taxons)
    taxons.each do |taxon|
      if taxon.position >= @taxon.position
        taxon.position += -1 unless taxon.position == 1
        taxon.save
      end
      
    end
  end
end