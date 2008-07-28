class Object
  def args_and_options(*args)
    options = Hash === args.last ? args.pop : {}
    return args, options
  end
end
