require 'test/helper'

class ProcessorTest < Test::Unit::TestCase
  should "instantiate and call #make when sent #make to the class" do
    processor = mock
    processor.expects(:make).with()
    Paperclip::Processor.expects(:new).with(:one, :two, :three).returns(processor)
    Paperclip::Processor.make(:one, :two, :three)
  end
end
