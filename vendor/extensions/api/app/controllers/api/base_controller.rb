class Api::BaseController < Spree::BaseController
  require_role 'admin'

  def self.resource_controller_for_api
    resource_controller

    index.response do |wants|
      wants.json { render :json => collection.to_json(collection_serialization_options) }
    end

    show.response do |wants|
      wants.json { render :json => object.to_json(object_serialization_options) }
    end

    create do
      wants.json { redirect_to object_url, :status => 201 }
      failure.wants.json { render :json => object_errors.to_json, :status => 422 }
    end

    update do
      wants.json { render :nothing => true }
      failure.wants.json { render :json => object_errors.to_json, :status => 422 }
    end

    define_method :end_of_association_chain do
      (parent? ? parent_association : model).scoped(:include  => eager_load_associations)
    end

    define_method :collection do
      @collection = search.all(:limit => 100)
    end
  end

  def access_denied
    render :text => 'access_denied', :status => 401
  end

  # Generic action to handle firing of state events on an object
  def event
    valid_events = model.state_machine.events.map(&:name)
    valid_events_for_object = object.state_transitions.map(&:event)

    if params[:e].blank?
      errors = t('api.errors.missing_event')
    elsif valid_events_for_object.include?(params[:e].to_sym)
      object.send("#{params[:e]}!")
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

    def search
      return @search unless @search.nil?
      @search = end_of_association_chain.searchlogic(params[:search])
      @search.order ||= "descend_by_created_at"
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
  
end