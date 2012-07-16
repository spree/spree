require 'active_model'
require 'active_support/concern'

module FakeModel
  extend ActiveSupport::Concern
  included do
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    # include ActiveModel::AttributeMethods
    include ActiveSupport::Callbacks

    define_callbacks :create

    def self.after_create(name)
      set_callback :create, :after, name
    end

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

  def reload
    #noop
  end

  def save
    #noop
  end
end
