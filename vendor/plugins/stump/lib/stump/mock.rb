class Object
  # Create a mock method on an object.  A mock object will place an expectation
  # on behavior and cause a test failure if it's not fulfilled.
  # 
  # ==== Examples
  #
  #    my_string = "a wooden rabbit"
  #    my_string.mock!(:retreat!, :return => "run away!  run away!")
  #    my_string.mock!(:question, :return => "what is the airspeed velocity of an unladen sparrow?")
  #    
  #    # test/your_test.rb
  #    my_string.retreat!    # => "run away!  run away!"
  #    # If we let the test case end at this point, it fails with:
  #    # Unmet expectation: #<Sparrow:1ee7> expected question
  #
  def mock!(method, options = {}, &block)    
    Stump::Mocks.add([self, method])
    
    behavior =  if block_given?
                  lambda do |*args| 
                    raise ArgumentError if block.arity >= 0 && args.length != block.arity
                    
                    Stump::Mocks.verify([self, method])
                    block.call(args)
                  end
                else
                  lambda do |*args|                     
                    Stump::Mocks.verify([self, method])
                    return options[:return]
                  end
                end

    meta_def method, &behavior
  end
end

module Kernel
  # Create a pure mock object rather than mocking specific methods on an object.
  #
  # ==== Examples
  # 
  #     my_mock = mock(:thing, :return => "whee!")
  #     my_mock.thing    # => "whee"
  #
  def mock(method, options = {}, &block)
    mock_object = Object.new
    mock_object.mock!(method, options, &block)
    mock_object
  end
end

