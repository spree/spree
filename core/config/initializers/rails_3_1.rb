module ActiveRecord
  # = Active Record Named \Scopes
  module NamedScope
    module ClassMethods
      protected

        def valid_scope_name?(name)
          respond_to?(name, true)
        end
    end
  end
end
