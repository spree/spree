class UserSessionsController < Spree::BaseController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  ssl_required :new, :create, :destroy, :update
  ssl_allowed :login_bar
    
  def new
    @user_session = UserSession.new
  end

  def create
    not_need_user_auto_creation = 
        user_without_openid(params[:user_session]) ||
        user_with_openid_exists?(:openid_identifier => params['openid.identity']) ||
        user_with_openid_exists?(params[:user_session]) 

    if not_need_user_auto_creation
      create_user_session(params[:user_session])   
    else
      create_user(params[:user_session])
    end
  end

  def destroy
    current_user_session.destroy
    session.clear
    flash[:notice] = t("logged_out")
    redirect_to products_path
  end
  
  def nav_bar
    render :partial => "shared/nav_bar"
  end
  
  private
  
  def user_with_openid_exists?(data)
    data && !data[:openid_identifier].blank? &&
      !!User.find(:first, :conditions => ["openid_identifier LIKE ?", "%#{data[:openid_identifier]}%"])
  end
  
  def user_without_openid(data)
    data && data[:openid_identifier].blank?
  end
  
  def create_user_session(data)
    @user_session = UserSession.new(data)
    @user_session.save do |result|
      if result
        # Should restore last uncompleted order and add current(guest) order to it, if exists.
        order = @user_session.record.orders.last(:conditions => {:completed_at => nil})
        if order
          if (session[:order_token] && guest_order = Order.find_by_token(session[:order_token]))
            guest_order.line_items.each do |line_item|
              order.add_variant(line_item.variant, line_item.quantity)
            end  
            order.save
            session[:return_to].gsub!(guest_order.number, order.number) if session[:return_to]
            guest_order.destroy
          end
          session[:order_token] = order.token
          session[:order_id] = order.id
        end
        
        respond_to do |format|
          format.html {
            flash[:notice] = t("logged_in_succesfully") unless session[:return_to]
            redirect_back_or_default products_path
          }
          format.js {
            user = @user_session.record
            render :json => {:ship_address => user.ship_address, :bill_address => user.bill_address}.to_json
          }
        end
      else
        respond_to do |format|
          format.html {
            flash.now[:error] = t("login_failed")
            render :action => :new
          }
          format.js { render :json => false }
        end
      end
    end
    redirect_back_or_default(products_path) unless performed?
  end
  
  def create_user(data)
    @user = User.new(data)

    @user.save do |result|
      if result
        flash[:notice] = t(:user_created_successfully) unless session[:return_to]
        redirect_back_or_default products_url
      else
        flash[:notice] = t(:missing_required_information)
        redirect_to :controller => :users, :action => :new, :user => {:openid_identifier => @user.openid_identifier}
      end
    end
  end

  def accurate_title
    I18n.t(:log_in)
  end
  
end
