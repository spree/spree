class String
  def step_name
    self
  end
  
  def arg_regexp
    ::Spec::Story::Step::PARAM_OR_GROUP_PATTERN
  end
end
