# As of 2016-08-17 rabl is broken on rails 5.
# This prevents errors when caching is enabled
if Rabl::VERSION == "0.13.0"
  # Remove the broken redefinition of digest
  Rabl::Digestor.class_eval do
    class << self
      remove_method :digest
    end
  end
else
  raise "Remove this monkey patch"
end
