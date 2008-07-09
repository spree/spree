class Admin::ConfigurationsController < Admin::BaseController

  before_filter :initialize_extension_links, :only => :index
  
  def index
    @app_configurations = AppConfiguration.find(:all)

    respond_to do |format|
      format.html
    end
  end

  def new
    @app_configuration = AppConfiguration.new()

    respond_to do |format|
      format.html
    end
  end

  def create
    @app_configuration = AppConfiguration.new(params[:app_configuration])
    @app_configuration.save

    respond_to do |format|
      format.html {
        if @app_configuration.valid?
          redirect_to admin_configuration_path(@app_configuration)
        else
          render :action => :new
        end
      }
    end
  end

  protected

  def initialize_extension_links
    @extension_links = []
  end
    
end
