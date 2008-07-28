module Spec
  module MetaClass
    def metaclass
      class << self; self; end
    end
  end
end