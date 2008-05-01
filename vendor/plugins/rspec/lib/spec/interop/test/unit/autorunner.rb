class Test::Unit::AutoRunner
  remove_method :process_args
  def process_args(argv)
    true
  end
end
