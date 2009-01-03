module Spec
  module Matchers
    def method_missing(sym, *args, &block) # :nodoc:
      return Matchers::Be.new(sym, *args) if sym.starts_with?("be_")
      return has(sym, *args) if sym.starts_with?("have_")
      super
    end
  end
end
