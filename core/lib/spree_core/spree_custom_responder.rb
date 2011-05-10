module Spree
  class Responder < ::ActionController::Responder #:nodoc:

    attr_accessor :on_success, :on_failure

    def initialize(controller, resources, options={})
      super

      class_name = controller.class.name.to_sym
      action_name = options.delete(:action_name)

      if result = Spree::BaseController.spree_responders[class_name].try(:[],action_name).try(:[], self.format.to_sym)
        self.on_success = (result.respond_to?(:call) ? result : result[:success])
        self.on_failure = (result.respond_to?(:call) ? result : result[:failure])
      end
    end

    def to_html
      super and return if !(on_success || on_failure)
      has_errors? ? controller.instance_exec(&on_failure) : controller.instance_exec(&on_success)
    end

    def to_format
      super and return if !(on_success || on_failure)
      has_errors? ? controller.instance_exec(&on_failure) : controller.instance_exec(&on_success)
    end

  end
end
