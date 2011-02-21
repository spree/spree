class Admin::UsersController < Admin::BaseController
  resource_controller

  #FIXME why is this needed?
  before_filter :check_json_authenticity, :only => :index

  before_filter :load_roles, :only => [:edit, :new, :update, :create]

  create.after :save_user_roles
  update.before :save_user_roles

  index.response do |wants|
    wants.html { render :action => :index }
    wants.json { render :json => json_data }
  end

  destroy.success.wants.js { render_js_for_destroy }

  private

  # Allow different formats of json data to suit different ajax calls
  def json_data
    json_format = params[:json_format] or 'default'
    case json_format
    when 'basic'
      collection.map {|u| {'id' => u.id, 'name' => u.email}}.to_json
    else
      collection.to_json( :only => [:email],
                          :include => { :bill_address => {:include => [:state, :country]},
                                        :ship_address => {:include => [:state, :country]}})
    end
  end

  def collection
    return @collection if @collection.present?
    if request.xhr?
      raise 'boom write test for this case if it is a valid case FIXME'
      @collection = User.includes(:bill_address => [:state, :country], :ship_address => [:state, :country])
      @collection = @collection.where("users.email like :search
                                  OR addresses.firstname like :search
                                  OR addresses.lastname like :search
                                  OR ship_addresses_users.firstname like :search
                                  OR ship_addresses_users.lastname like :search",{:search => "#{params[:q].strip}%"})
      @collection = @collection.limit(params[:limit] || 100)
    else
      @search = User.metasearch(params[:search])
      @collection = @search.paginate(:per_page => Spree::Config[:admin_products_per_page], :page => params[:page])
    end
  end

  def load_roles
    @roles = Role.all
  end

  #FIXME write tests with user_role in auth
  def save_user_roles
    return unless params[:user]
    return unless @user.respond_to?(:roles)
    @user.roles.delete_all
    params[:user][:role] ||= {}
    Role.all.each { |role|
      @user.roles << role unless params[:user][:role][role.name].blank?
    }
    params[:user].delete(:role)
  end
end
