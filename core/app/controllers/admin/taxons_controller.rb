class Admin::TaxonsController < Admin::BaseController
  include Railslove::Plugins::FindByParam::SingletonMethods
  resource_controller
  before_filter :load_object, :only => [:selected, :available, :remove]
  before_filter :load_permalink_part, :only => :edit
  belongs_to :product, :taxonomy

  create.wants.html {render :text => @taxon.id}
  update.wants.html {redirect_to edit_admin_taxonomy_url(@taxonomy)}
  update.wants.json {render :json => @taxon.to_json()}

  destroy.wants.html {render :text => ""}
  destroy.success.wants.js { render_js_for_destroy }

  create.before :create_before
  update.before :update_before
  update.after :update_after

  def selected
    @taxons = @product.taxons
  end

  def available
    if params[:q].blank?
      @available_taxons = []
    else
      @available_taxons = Taxon.where('lower(name) LIKE ?', "%#{params[:q].downcase}%")
    end
    @available_taxons.delete_if { |taxon| @product.taxons.include?(taxon) }
    respond_to do |format|
      format.js {render :layout => false}
    end

  end

  def remove
    @product.taxons.delete(@taxon)
    @product.save
    @taxons = @product.taxons
    render_js_for_destroy
  end

  def select
    @product = Product.find_by_param!(params[:product_id])
    @taxon = Taxon.find(params[:id])
    @product.taxons << @taxon
    @product.save
    @taxons = @product.taxons
    render :layout => false
  end

  private
  def create_before
    @taxon.taxonomy_id = params[:taxonomy_id]
  end

  def update_before
    parent_id = params[:taxon][:parent_id]
    new_position = params[:taxon][:position]

    if parent_id || new_position #taxon is being moved
      new_parent = parent_id.nil? ? @taxon.parent : Taxon.find(parent_id.to_i)
      new_position = new_position.nil? ? -1 : new_position.to_i

      # Bellow is a very complicated way of finding where in nested set we
      # should actually move the taxon to achieve sane results,
      # JS is giving us the desired position, which was awesome for previous setup,
      # but now it's quite complicated to find where we should put it as we have
      # to differenciate between moving to the same branch, up down and into
      # first position.
      new_siblings = new_parent.children
      if new_position <= 0 && new_siblings.empty?
        @taxon.move_to_child_of(new_parent)
      elsif new_parent.id != @taxon.parent_id
        if new_position == 0
          @taxon.move_to_left_of(new_siblings.first)
        else
          @taxon.move_to_right_of(new_siblings[new_position-1])
        end
      elsif new_position < new_siblings.index(@taxon)
        @taxon.move_to_left_of(new_siblings[new_position]) # we move up
      else
        @taxon.move_to_right_of(new_siblings[new_position]) # we move down
      end
      # Reset legacy position, if any extensions still rely on it
      new_parent.children.reload.each{|t| t.update_attribute(:position, t.position)}

      if parent_id
        @taxon.reload
        @taxon.set_permalink
        @taxon.save!
        @update_children = true
      end
    end

    if params.key? "permalink_part"
      parent_permalink = @taxon.permalink.split("/")[0...-1].join("/")
      parent_permalink += "/" unless parent_permalink.blank?
      params[:taxon][:permalink] = parent_permalink + params[:permalink_part]
    end
    #check if we need to rename child taxons if parent name or permalink changes
    @update_children = true if params[:taxon][:name] != @taxon.name || params[:taxon][:permalink] != @taxon.permalink
  end

  def update_after
    #rename child taxons
    if @update_children
      @taxon.descendants.each do |taxon|
        taxon.reload
        taxon.set_permalink
        taxon.save!
      end
    end
  end

  def reposition_taxons(taxons)
    taxons.each_with_index do |taxon, i|
      taxon.position = i
      taxon.save!
    end
  end

  def load_permalink_part
    @permalink_part = object.permalink.split("/").last
  end
end
