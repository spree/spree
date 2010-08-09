# This is a modified version of wizardly plugin (Jeff Patmon), which itself is based on the validationgroup
# plugin (akira)
module ValidationGroup
  module ActiveRecord
    module ActsMethods # extends ActiveRecord::Base
      def self.extended(base)
        # Add class accessor which is shared between all models and stores
        # validation groups defined for each model
        base.class_eval do
          cattr_accessor :validation_group_classes
          self.validation_group_classes = {}

          def self.validation_group_order; @validation_group_order; end
          def self.validation_groups(all_classes = false)
            return (self.validation_group_classes[self] || {}) unless all_classes
            klasses = ValidationGroup::Util.current_and_ancestors(self).reverse
            hash = Hash.new
            klasses.each do |klass|
              hash.merge! self.validation_group_classes[klass]
            end
            hash
          end
        end
      end

      def validation_group(name, options={})
        self_groups = (self.validation_group_classes[self] ||= {})
        self_groups[name.to_sym] = case options[:fields]
when Array then options[:fields]
when Symbol, String then [options[:fields].to_sym]
else []
end
        # jeffp: capture the declaration order for this class only (no
        # superclasses)
        (@validation_group_order ||= []) << name.to_sym

        unless included_modules.include?(InstanceMethods)
          # jeffp: added reader for current_validation_fields
          attr_reader :current_validation_group, :current_validation_fields
          include InstanceMethods
        end
      end
    end

    module InstanceMethods # included in every model which calls validation_group
      #needs testing
# def reset_fields_for_validation_group(group)
# group_classes = self.class.validation_group_classes
# found = ValidationGroup::Util.current_and_ancestors(self.class).find do |klass|
# group_classes[klass] && group_classes[klass].include?(group)
# end
# if found
# group_classes[found][group].each do |field|
# self[field] = nil
# end
# end
# end
      def enable_validation_group(group)
        # Check if given validation group is defined for current class or one of
        # its ancestors
        group_classes = self.class.validation_group_classes
        found = ValidationGroup::Util.current_and_ancestors(self.class).
          find do |klass|
          group_classes[klass] && group_classes[klass].include?(group)
        end
        if found
          @current_validation_group = group
          # jeffp: capture current fields for performance optimization
          @current_validation_fields = group_classes[found][group].clone
        end
      end

      def disable_validation_group
        @current_validation_group = nil
        # jeffp: delete fields
        @current_validation_fields = nil
      end

      def reject_non_validation_group_errors
        return unless validation_group_enabled?
        self.errors.remove_on(@current_validation_fields)
      end

      # jeffp: optimizer for someone writing custom :validate method -- no need
      # to validate fields outside the current validation group note: could also
      # use in validation modules to improve performance
      def should_validate?(attribute)
        !self.validation_group_enabled? || (@current_validation_fields && @current_validation_fields.include?(attribute.to_sym))
      end

      def validation_group_enabled?
        respond_to?(:current_validation_group) && !current_validation_group.nil?
      end

      # eliminates need to use :enable_validation_group before :valid? call --
      # nice
      def valid_with_validation_group?(group=nil)
        self.enable_validation_group(group) if group
        valid_without_validation_group?
      end
    end

    module Errors # included in ActiveRecord::Errors
      def add_with_validation_group(attribute,
          msg = @@default_error_messages[:invalid], *args,
          &block)
        # jeffp: setting @current_validation_fields and use of should_validate? optimizes code
        add_error = @base.respond_to?(:should_validate?) ? @base.should_validate?(attribute.to_sym) : true
        add_without_validation_group(attribute, msg, *args, &block) if add_error
      end

      def remove_on(attributes)
        return unless attributes
        attributes = [attributes] unless attributes.is_a?(Array)
        @errors.reject!{|k,v| !attributes.include?(k.to_sym)}
      end

      def self.included(base) #:nodoc:
        base.class_eval do
          alias_method_chain :add, :validation_group
        end
      end
    end
  end

  module Util
    # Return array consisting of current and its superclasses down to and
    # including base_class.
    def self.current_and_ancestors(current)
      klasses = []
      klasses << current
      root = current.base_class
      until current == root
        current = current.superclass
        klasses << current
      end
      klasses
    end
  end
end

# jeffp: moved from init.rb for gemification purposes --
# require 'validation_group' loads everything now, init.rb requires 'validation_group' only
