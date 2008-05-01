class Object
  def args_and_options(*args)
    options = Hash === args.last ? args.pop : {}
    return args, options
  end

  def metaclass
    class << self; self; end
  end
end
