require File.join(File.dirname(__FILE__), *%w[helper])

["example_groups","interop"].each do |dir|
  require File.join(File.dirname(__FILE__), "#{dir}/stories")
end
