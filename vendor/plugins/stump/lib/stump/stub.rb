class Object
  # Create a stub method on an object.  Simply returns a value for a method call on
  # an object.
  # 
  # ==== Examples
  #
  #    my_string = "a wooden rabbit"
  #    my_string.stub!(:retreat!, :return => "run away!  run away!")
  #    
  #    # test/your_test.rb
  #    my_string.retreat!    # => "run away!  run away!"
  #
  def stub!(method, options = {}, &block)
    behavior = (block_given? ? block : proc { return options[:return] })

    meta_def method, &behavior
  end
end

module Kernel
  # Create a pure stub object.
  #
  # ==== Examples
  # 
  #     stubbalicious = stub(:failure, "wat u say?")
  #     stubbalicious.failure     # => "wat u say?"
  #
  def stub(method, options = {}, &block)
    stub_object = Object.new
    stub_object.stub!(method, options, &block)
    
    stub_object
  end
end