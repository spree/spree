class Admin::ZonesController < Admin::BaseController
  resource_controller  
  
  before_filter :load_data

  create.after do
    set_members
  end
  
  update.after do
    object.members.clear
    set_members
  end
  
  create.response do |wants|
    wants.html { redirect_to collection_url }
  end

  update.response do |wants|
    wants.html { redirect_to collection_url }
  end
  
  index.response do |wants|
    wants.html
    wants.js do
      @zones = Zone.find(:all, :conditions => ['lower(name) LIKE ?', "%#{params[:q].downcase}%"])
      render :template => "admin/zones/index.js.erb", :layout => false
    end
  end  
  
  private
    def collection
      @collection ||= end_of_association_chain.find(:all, :order => :name, :page => {:size => 10, :current => params[:p], :first => 1})
    end  

    def load_data
      @countries = Country.all
    end
    
    def set_members
      return unless params[:member_names]
      clazz = params[:type].classify.constantize
      params[:member_names].each do |name|
        member = clazz.find_by_name(name) unless name.blank?        
        object.members << member unless member.nil?
      end
      object.save
    end
end
