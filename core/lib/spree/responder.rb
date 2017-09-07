module Spree
  class Responder < ::ActionController::Responder #:nodoc:
    attr_accessor :on_success, :on_failure

    def initialize(controller, resources, options = {})
      super

      class_name = controller.class.name.to_sym
      action_name = options.delete(:action_name)

      if result = Spree::BaseController.spree_responders[class_name].try(:[], action_name).try(:[], format.to_sym)
        self.on_success = handler(controller, result, :success)
        self.on_failure = handler(controller, result, :failure)
      end
    end

    def to_html
      super && return unless on_success || on_failure
      has_errors? ? controller.instance_exec(&on_failure) : controller.instance_exec(&on_success)
    end

    def to_format
      super && return unless on_success || on_failure
      has_errors? ? controller.instance_exec(&on_failure) : controller.instance_exec(&on_success)
    end

    private

    def handler(controller, result, status)
      return result if result.respond_to? :call

      case result
      when Hash
        if result[status].is_a? Symbol
          controller.method(result[status])
        else
          result[status]
        end
      when Symbol
        controller.method(result)
      end
    end
  end
end
