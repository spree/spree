class Object # :nodoc:
  def self.path2class(klassname)
    klassname.split('::').inject(Object) { |k,n| k.const_get n }
  end
end
