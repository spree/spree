class Spree::Api::BaseController < Spree::BaseController
  before_filter :check_http_authorization
  before_filter :load_resource
  skip_before_filter :verify_authenticity_token, :if => lambda { admin_token_passed_in_headers }

  respond_to :json

  def index
    respond_with(@collection) do |format|
      format.json { render :json => @collection.to_json(collection_serialization_options) }
    end
  end

  def show
    respond_with(@object) do |format|
      format.json { render :json => @object.to_json(object_serialization_options) }
    end
  end

  def create
    if @object.save
      render :text => "Resource created\n", :status => 201, :location => object_url
    else
      respond_with(@object.errors, :status => 422)
    end
  end

  def update
    if @object.update_attributes(params[object_name])
      render :nothing => true
    else
      respond_with(@object.errors, :status => 422)
    end
  end

  def admin_token_passed_in_headers
    request.headers['HTTP_AUTHORIZATION'].present?
  end

  def access_denied
    render :text => 'access_denied', :status => 401
  end

  # Generic action to handle firing of state events on an object
  def event
    valid_events = model_class.state_machine.events.map(&:name)
    valid_events_for_object = @object ? @object.state_transitions.map(&:event) : []

    if params[:e].blank?
      errors = t('api.errors.missing_event')
    elsif valid_events_for_object.include?(params[:e].to_sym)
      @object.send("#{params[:e]}!")
      errors = nil
    elsif valid_events.include?(params[:e].to_sym)
      errors = t('api.errors.invalid_event_for_object', :events => valid_events_for_object.join(','))
    else
      errors = t('api.errors.invalid_event', :events => valid_events.join(','))
    end

    respond_to do |wants|
      wants.json do
        if errors.blank?
          render :nothing => true
        else
          render :json => errors.to_json, :status => 422
        end
      end
    end
  end

  protected
    def model_class
      "Spree::#{controller_name.classify}".constantize
    end

    def object_name
      controller_name.singularize
    end

    def load_resource
      if member_action?
        @object ||= load_resource_instance
        instance_variable_set("@#{object_name}", @object)
      else
        @collection ||= collection
        instance_variable_set("@#{controller_name}", @collection)
      end
    end

    def load_resource_instance
      if new_actions.include?(params[:action].to_sym)
        build_resource
      elsif params[:id]
        find_resource
      end
    end

    def parent
      nil
    end

    def find_resource
      if parent.present?
        parent.send(controller_name).find(params[:id])
      else
        model_class.includes(eager_load_associations).find(params[:id])
      end
    end

    def build_resource
      if parent.present?
        parent.send(controller_name).build(params[object_name])
      else
        model_class.new(params[object_name])
      end
    end

    def collection
      return @search unless @search.nil?
      params[:search] = {} if params[:search].blank?
      params[:q] = {} if params[:q].blank?
      # Backwards compatibility, to be removed in the next version of API
      params[:search][:meta_sort] = 'created_at.desc' if params[:search][:meta_sort].blank?
      params[:q][:s] = params[:search][:meta_sort]

      scope = parent.present? ? parent.send(controller_name) : model_class.scoped

      @search = scope.search(params[:q]).result.limit(100)
      @search
    end

    def collection_serialization_options
      {}
    end

    def object_serialization_options
      {}
    end

    def eager_load_associations
      nil
    end

    def object_errors
      {:errors => object.errors.full_messages}
    end

    def object_url(object = nil, options = {})
      target = object ? object : @object
      if parent.present?
        send "admin_#{parent[:model_name]}_#{object_name}_url", parent, target, options
      else
        send "admin_#{object_name}_url", target, options
      end
    end

    def collection_actions
      [:index]
    end

    def member_action?
      !collection_actions.include? params[:action].to_sym
    end

    def new_actions
      [:new, :create]
    end

  private
    def check_http_authorization
      if request.headers['HTTP_AUTHORIZATION'].blank?
        render :text => "Access Denied\n", :status => 401
      end
    end
end
