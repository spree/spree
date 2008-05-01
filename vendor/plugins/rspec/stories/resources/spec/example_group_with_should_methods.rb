$:.push File.join(File.dirname(__FILE__), *%w[.. .. .. lib])
require 'spec'

class MySpec < Spec::ExampleGroup
  def should_pass_with_should
    1.should == 1
  end

  def should_fail_with_should
    1.should == 2
  end
end