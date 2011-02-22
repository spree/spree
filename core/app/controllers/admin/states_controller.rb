class Admin::StatesController < Admin::BaseController
  resource_controller

  before_filter :load_country, :only => [:index, :edit, :update, :new, :create]
  before_filter :load_state, :only => [:edit]

  def index
    @countries = Country.order('name')
    @states = @country.states.order('name')
    respond_to do |format|
      format.html
      format.js { render :partial => 'state_list.html.erb' }
    end
  end

  def new
    @state = @country.states.build
    respond_to do |format|
      format.html { render :layout => !request.xhr? }
    end
  end

  def create
    @state = @country.states.build(params[:state])
    respond_to do |format|
      if @state.save
        format.html {
          flash.notice = "Successfully created!"
          redirect_to admin_country_states_url(@country)
        }
      else
        format.html { render :action => 'new' }
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
    end
  end

  def update
    @state = State.find(params[:id])
    respond_to do |format|
      if @state.update_attributes(params[:state])
        format.html {
          flash.notice = "Successfully Updated!"
          redirect_to admin_country_states_url(@country)
        }
      else
        format.html { render :action => 'edit' }
      end
    end
  end

  private

  def load_country
    @country = Country.find(params[:country_id])
  end

  def load_state
    @state = State.find(params[:id])
  end

end
