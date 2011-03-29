module SubclassRegistration
  extend ActiveSupport::Concern

  included do
    cattr_accessor :registered_classes
    self.registered_classes = []
  end

  module ClassMethods

    def register
      registered_classes << self
    end

    def registered_class_names
      registered_classes.map(&:name)
    end

  end

end
