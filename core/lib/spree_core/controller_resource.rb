module Spree
  class ControllerResource < ::CanCan::ControllerResource
    def initialize(controller, *args)
      super
      @options[:find_by] = :permalink if resource_base.new.respond_to?(:permalink)
    end
    
    protected
    
    def collection_instance=(instance)
      @controller.instance_variable_set("@collection", instance)
      @controller.instance_variable_set("@#{instance_name.to_s.pluralize}", instance)
    end
    
    def resource_instance=(instance)
      @controller.instance_variable_set("@object", instance)
      @controller.instance_variable_set("@#{instance_name}", instance)
    end
    
    def load_collection
      if @controller.respond_to? :collection
        @controller.send :collection
      else
        resource_base.accessible_by(current_ability)
      end
    end
    
    def load_resource_instance
      if !parent? && new_actions.include?(@params[:action].to_sym)
        if @controller.respond_to? :build_resource
          @controller.send :build_resource
        else
          build_resource
        end
      elsif id_param || @options[:singleton]
        if @controller.respond_to? :find_resource
          @controller.send :find_resource
        else
          find_resource
        end
      end
    end
  end
  
end

CanCan::ControllerAdditions::ClassMethods.module_eval do
  def cancan_resource_class
    ::Spree::ControllerResource
  end
end
