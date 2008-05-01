class Regexp
  def step_name
    self.source
  end
  
  def arg_regexp
    ::Spec::Story::Step::PARAM_OR_GROUP_PATTERN
  end
end