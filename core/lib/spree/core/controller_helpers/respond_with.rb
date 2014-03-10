module Spree
  module Core
    module ControllerHelpers
      module RespondWith
        extend ActiveSupport::Concern

        included do
          cattr_accessor :spree_responders
          self.spree_responders = {}
        end

        module ClassMethods
          def clear_overrides!
            self.spree_responders = {}
          end

          def respond_override(options={})
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
                options = {action_name.to_sym => {format_name.to_sym => {:success => format_value}}}
              end

              self.spree_responders.deep_merge!(self.name.to_sym => options)
            end
          end
        end
      end
    end
  end
end
