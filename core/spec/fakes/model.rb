require 'active_model'

module FakeModel
  def self.included(base)
    base.class_eval do
      include ActiveModel::Validations
      include ActiveModel::Validations::Callbacks
      include ActiveModel::AttributeMethods

      def self.belongs_to(name, options={})
        attr_accessor name
      end

      def self.has_many(name, options={})
        attr_accessor name
        # Stolen from abstract_controller/callbacks
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{name}
          @#{name} ||= []
        end
        RUBY_EVAL
      end

      def self.accepts_nested_attributes_for(*args)
        #noop
      end

      def self.attr_accessible(*args)
        #noop
      end
    end
  end

  def reload
    #noop
  end

  def save
    #noop
  end
end
