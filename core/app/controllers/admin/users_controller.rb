class Admin::UsersController < Admin::ResourceController
  # http://spreecommerce.com/blog/2010/11/02/json-hijacking-vulnerability/
  before_filter :check_json_authenticity, :only => :index
  before_filter :load_roles, :only => [:edit, :new, :update, :create]

  create.after :save_user_roles
  update.before :save_user_roles

  def index
    respond_with(@collection) do |format|
      format.html
      format.json { render :json => json_data }
    end
  end

  protected

  def collection
    return @collection if @collection.present?
    unless request.xhr?
      @search = User.registered.metasearch(params[:search])
      @collection = @search.paginate(:per_page => Spree::Config[:admin_products_per_page], :page => params[:page])
    else
      @collection = User.includes(:bill_address => [:state, :country], :ship_address => [:state, :country]).
                        where("users.email #{LIKE} :search
                               OR addresses.firstname #{LIKE} :search
                               OR addresses.lastname #{LIKE} :search
                               OR ship_addresses_users.firstname #{LIKE} :search
                               OR ship_addresses_users.lastname #{LIKE} :search",
                               {:search => "#{params[:q].strip}%"}).
                        limit(params[:limit] || 100)
    end
  end

  def save_user_roles
    return unless params[:user]
    return unless @user.respond_to?(:roles) # since roles are technically added by the auth module
    @user.roles.delete_all
    params[:user][:role] ||= {}
    Role.all.each { |role|
      @user.roles << role unless params[:user][:role][role.name].blank?
    }
    params[:user].delete(:role)
  end

  private

  # Allow different formats of json data to suit different ajax calls
  def json_data
    json_format = params[:json_format] or 'default'
    case json_format
    when 'basic'
      collection.map {|u| {'id' => u.id, 'name' => u.email}}.to_json
    else
      collection.to_json(:include =>
        {:bill_address => {:include => [:state, :country]},
        :ship_address => {:include => [:state, :country]}})
    end
  end

  def load_roles
    @roles = Role.all
  end

end
