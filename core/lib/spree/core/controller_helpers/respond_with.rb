require 'spree/responder'

module ActionController
  class Base
    def respond_with(*resources, &block)
      if Spree::BaseController.spree_responders.keys.include?(self.class.to_s.to_sym)
        # Checkout AS Array#extract_options! and original respond_with
        # implementation for a better picture of this hack
        if resources.last.is_a? Hash
          resources.last[:action_name] = action_name.to_sym
        else
          resources.push action_name: action_name.to_sym
        end
      end

      super
    end
  end
end

module Spree
  module Core
    module ControllerHelpers
      module RespondWith
        extend ActiveSupport::Concern

        included do
          cattr_accessor :spree_responders
          self.spree_responders = {}
          self.responder = Spree::Responder
        end

        module ClassMethods
          def clear_overrides!
            self.spree_responders = {}
          end

          def respond_override(options = {})
            unless options.blank?
              action_name = options.keys.first
              action_value = options.values.first

              if action_name.blank? || action_value.blank?
                raise ArgumentError, "invalid values supplied #{options.inspect}"
              end

              format_name = action_value.keys.first
              format_value = action_value.values.first

              if format_name.blank? || format_value.blank?
                raise ArgumentError, "invalid values supplied #{options.inspect}"
              end

              if format_value.is_a?(Proc)
                options = { action_name.to_sym => { format_name.to_sym => { success: format_value } } }
              end

              spree_responders.deep_merge!(name.to_sym => options)
            end
          end
        end
      end
    end
  end
end
