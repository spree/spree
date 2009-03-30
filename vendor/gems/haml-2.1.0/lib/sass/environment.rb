module Sass
  class Environment
    attr_reader :parent

    def initialize(parent = nil)
      @vars = {}
      @mixins = {}
      @parent = parent
    end

    def self.inherited_hash(name)
      class_eval <<RUBY, __FILE__, __LINE__ + 1
        def #{name}(name)
          @#{name}s[name] || @parent && @parent.#{name}(name)
        end

        def set_#{name}(name, value)
          if @parent && @parent.#{name}(name)
            @parent.set_#{name}(name, value)
          else
            @#{name}s[name] = value
          end
        end

        def set_local_#{name}(name, value)
          @#{name}s[name] = value
        end
RUBY
    end
    inherited_hash :var
    inherited_hash :mixin
  end
end
