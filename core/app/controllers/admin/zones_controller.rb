class Admin::ZonesController < Admin::BaseController
  resource_controller  
  
  before_filter :load_data

  create.response do |wants|
    wants.html { redirect_to collection_url }
  end

  update.response do |wants|
    wants.html { redirect_to collection_url }
  end
  
  destroy.success.wants.js { render_js_for_destroy }
  
  private
  def build_object
    @object ||= end_of_association_chain.send parent? ? :build : :new, object_params
    @object.zone_members.build() if @object.zone_members.empty?  
    @object
  end

  def collection
    params[:search] ||= {}
    params[:search][:order] ||= "ascend_by_name"
    @search = end_of_association_chain.searchlogic(params[:search])
    @collection = @search.do_search.paginate(:per_page => Spree::Config[:orders_per_page], :page => params[:page])
  end  

  def load_data
    @countries = Country.all.sort
    @states = State.all.sort
    @zones = Zone.all.sort
  end
end
