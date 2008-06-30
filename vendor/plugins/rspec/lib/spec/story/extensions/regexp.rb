class Regexp
  def step_name
    self.source.gsub '\\$', '$$'
  end
  
  def arg_regexp
    ::Spec::Story::Step::PARAM_OR_GROUP_PATTERN
  end
end
