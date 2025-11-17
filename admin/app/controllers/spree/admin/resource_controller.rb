class Spree::Admin::ResourceController < Spree::Admin::BaseController
  include Spree::Admin::Callbacks

  helper_method :new_object_url, :edit_object_url, :object_url, :collection_url, :model_class
  before_action :load_resource
  before_action :set_currency, :set_current_store, only: [:new, :create]

  rescue_from ActiveRecord::RecordNotFound, with: :resource_not_found

  def index
    @collection = collection
  end

  # GET /admin/<resource_name>/new
  def new
    invoke_callbacks(:new_action, :before)
  end

  # GET /admin/<resource_name_plural>/<id>/edit
  def edit
    invoke_callbacks(:edit_action, :before)
  end

  # PUT /admin/<resource_name_plural>/<id>
  def update
    invoke_callbacks(:update, :before)
    if @object.update(permitted_resource_params)
      set_current_store
      remove_assets(%w[asset image square_image])

      invoke_callbacks(:update, :after)
      respond_to do |format|
        if update_turbo_stream_enabled?
          format.turbo_stream do
            flash.now[:success] = message_after_update
          end
        end
        format.html do
          flash[:success] = message_after_update
          redirect_to location_after_save, status: :see_other
        end
      end
    else
      invoke_callbacks(:update, :fails)
      respond_to do |format|
        if update_turbo_stream_enabled?
          format.turbo_stream do
            flash.now[:error] = @object.errors.full_messages.join(', ')
          end
        end
        format.html { render action: :edit, status: :unprocessable_entity }
      end
    end
  end

  # POST /admin/<resource_name_plural>
  def create
    invoke_callbacks(:create, :before)
    set_created_by
    @object.attributes = permitted_resource_params
    if @object.save
      invoke_callbacks(:create, :after)
      respond_to do |format|
        if create_turbo_stream_enabled?
          format.turbo_stream do
            flash.now[:success] = message_after_create
          end
        end
        format.html do
          flash[:success] = message_after_create
          redirect_to location_after_create, status: :see_other
        end
      end
    else
      invoke_callbacks(:create, :fails)
      respond_to do |format|
        if create_turbo_stream_enabled?
          format.turbo_stream do
            flash.now[:error] = @object.errors.full_messages.join(', ')
          end
        end
        format.html { render action: :new, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/<resource_name_plural>/<id>
  def destroy
    invoke_callbacks(:destroy, :before)
    if @object.destroy
      invoke_callbacks(:destroy, :after)

      respond_to do |format|
        if destroy_turbo_stream_enabled?
          format.turbo_stream do
            flash.now[:success] = flash_message_for(@object, :successfully_removed)
          end
        end
        format.html do
          flash[:success] = flash_message_for(@object, :successfully_removed)
          redirect_to location_after_destroy, status: :see_other
        end
      end
    else
      invoke_callbacks(:destroy, :fails)

      respond_to do |format|
        if destroy_turbo_stream_enabled?
          format.turbo_stream do
            flash.now[:error] = @object.errors.full_messages.to_sentence
          end
        end
        format.html do
          flash[:error] = @object.errors.full_messages.to_sentence
        end
      end
    end
  end

  protected

  class << self
    attr_accessor :parent_data

    def belongs_to(model_name, options = {})
      @parent_data ||= {}
      @parent_data[:model_name] = model_name
      @parent_data[:model_class] = model_name.to_s.classify.constantize
      @parent_data[:find_by] = options[:find_by] || :id
    end
  end

  def model_class
    @model_class ||= resource.model_class
  end

  def resource_not_found
    flash[:error] = flash_message_for(model_class.new, :not_found)
    redirect_to collection_url, status: :see_other
  end

  # Returns the resource for the current controller
  # @return [Spree::Admin::Resource]
  def resource
    return @resource if @resource

    parent_model_name = parent_data[:model_name] if parent_data
    @resource = Spree::Admin::Resource.new controller_path, controller_name, parent_model_name, object_name
  end

  # Loads the resource for the current controller
  # @return [Spree::Admin::Resource]
  def load_resource
    if member_action?
      @object ||= load_resource_instance

      # call authorize! a third time (called twice already in Admin::BaseController)
      # this time we pass the actual instance so fine-grained abilities can control
      # access to individual records, not just entire models.
      authorize! action, @object if @object.present?

      instance_variable_set("@#{resource.object_name}", @object)
    else
      @collection ||= collection

      # note: we don't call authorize here as the collection method should use
      # CanCan's accessible_by method to restrict the actual records returned

      instance_variable_set("@#{controller_name}", @collection)
    end
  end

  def load_resource_instance
    if new_actions.include?(action)
      build_resource
    elsif params[:id]
      find_resource
    end
  end

  def parent_data
    self.class.parent_data
  end

  def parent
    if parent_data.present?
      base_scope = parent_data[:model_class].try(:for_store, current_store) || parent_data[:model_class]

      @parent ||= base_scope.
                  # Don't use `find_by_attribute_name` to workaround globalize/globalize#423 bug
                  send(:find_by, parent_data[:find_by].to_s => params["#{resource.model_name}_id"])
      instance_variable_set("@#{resource.model_name}", @parent)

      raise ActiveRecord::RecordNotFound if @parent.nil?

      @parent
    end
  end

  def find_resource
    base_scope = if parent_data.present?
                   parent.send(controller_name)
                 else
                   model_class.try(:for_store, current_store) || model_class
                end

    if model_class.try(:friendly)
      base_scope.friendly.find(params[:id])
    else
      base_scope.find(params[:id])
    end
  end

  def build_resource
    if parent_data.present?
      parent.send(controller_name).build
    else
      model_class.new
    end
  end

  # Returns the collection of resources (as a scope)
  # @return [ActiveRecord::Relation]
  def scope
    return parent.send(controller_name) if parent_data.present?

    base_scope = model_class.try(:for_store, current_store) || model_class
    if defined?(current_vendor) && current_vendor.present? && model_class.respond_to?(:with_vendor)
      base_scope = base_scope.with_vendor(current_vendor)
    end

    if model_class.respond_to?(:accessible_by) &&
        !current_ability.has_block?(params[:action], model_class)
      base_scope.accessible_by(current_ability, action).includes(collection_includes)
    else
      base_scope.includes(collection_includes)
    end
  end

  # keeping this as @search for backwards compatibility
  # @return [Ransack::Search]
  def search_collection
    @search ||= begin
      params[:q] ||= {}
      params[:q][:s] ||= collection_default_sort if collection_default_sort.present?
      scope.ransack(params[:q])
    end
  end

  # Returns the filtered and paginated ransack results
  # @return [ActiveRecord::Relation]
  def collection
    @collection ||= search_collection.result(distinct: true).page(params[:page]).per(params[:per_page])
  end

  def collection_includes
    []
  end

  # Override in child controllers to set default sort order
  # @return [String, nil] Ransack sort string (e.g., "name asc", "created_at desc")
  def collection_default_sort
    nil
  end

  # Returns the URL to redirect to after destroying a resource
  # @return [String]
  def location_after_destroy
    collection_url
  end

  # Returns the URL to redirect to after creating a resource
  # @return [String]
  def location_after_create
    location_after_save
  end

  # Returns the URL to redirect to after saving a resource (update or create)
  # @return [String]
  def location_after_save
    edit_object_url(@object)
  end

  # Returns the flash message after creating a resource
  # @return [String]
  def message_after_create
    flash_message_for(@object, :successfully_created)
  end

  # Returns the flash message after updating a resource
  # @return [String]
  def message_after_update
    flash_message_for(@object, :successfully_updated)
  end

  # Sets the current store for the resource, if resource is store related
  # @return [void]
  def set_current_store
    return if @object.nil?

    ensure_current_store(@object)
  end

  # Sets the created_by with the current admin user for the resource, if resource is created_by related
  # @return [void]
  def set_created_by
    return if @object.nil?

    @object.created_by = try_spree_current_user if @object.respond_to?(:created_by_id)
  end

  def set_currency
    return if @object.nil?

    @object.currency = current_currency if model_class.method_defined?(:currency=)
    @object.cost_currency = current_currency if model_class.method_defined?(:cost_currency=)
  end

  # URL helpers

  # Returns the URL to redirect to after creating a resource
  # @return [String]
  def new_object_url(options = {})
    if parent_data.present?
      spree.new_polymorphic_url([:admin, parent, model_class], options)
    else
      spree.new_polymorphic_url([:admin, model_class], options)
    end
  end

  # Returns the URL to edit a resource
  # @return [String]
  def edit_object_url(object, options = {})
    if parent_data.present?
      spree.send "edit_admin_#{resource.model_name}_#{resource.object_name}_url",
                 parent, object, options
    else
      spree.send "edit_admin_#{resource.object_name}_url", object, options
    end
  end

  # Returns the URL to the resource
  # @return [String]
  def object_url(object = nil, options = {})
    target = object || @object
    if parent_data.present?
      spree.send "admin_#{resource.model_name}_#{resource.object_name}_url", parent, target, options
    else
      spree.send "admin_#{resource.object_name}_url", target, options
    end
  end

  # Returns the URL to the collection of resources
  # @return [String]
  def collection_url(options = {})
    if parent_data.present?
      spree.polymorphic_url([:admin, parent, model_class], options)
    else
      spree.polymorphic_url([:admin, model_class], options)
    end
  end

  # This method should be overridden when object_name does not match the controller name
  def object_name; end

  # Allow all attributes to be updatable.
  #
  # Other controllers can, should, override it to set custom logic
  def permitted_resource_params
    raise NotImplementedError, "You must implement the permitted_resource_params method"
  end

  # Returns the actions that are collection actions
  # @return [Array]
  def collection_actions
    [:index, :select_options, :bulk_modal, :bulk_status_update,
     :bulk_add_to_taxons, :bulk_remove_from_taxons,
     :bulk_add_tags, :bulk_remove_tags, :bulk_destroy]
  end

  # Returns true if the current action is a member action
  # @return [Boolean]
  def member_action?
    !collection_actions.include? action
  end

  # Returns the actions that are new actions
  # @return [Array]
  def new_actions
    [:new, :create]
  end

  def create_turbo_stream_enabled?
    false
  end

  def update_turbo_stream_enabled?
    false
  end

  def destroy_turbo_stream_enabled?
    false
  end
end
