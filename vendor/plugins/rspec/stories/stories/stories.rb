require File.join(File.dirname(__FILE__), *%w[.. helper])
require File.join(File.dirname(__FILE__), *%w[steps multiline_steps])

with_steps_for :multiline_steps do
  run File.dirname(__FILE__) + "/multiline_steps.story"
end