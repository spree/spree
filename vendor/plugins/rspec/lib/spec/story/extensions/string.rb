class String
  def step_name
    self
  end
  
  def arg_regexp
    ::Spec::Story::Step::PARAM_PATTERN
  end
end