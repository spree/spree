require 'spec/mocks/framework'
require 'spec/mocks/methods'
require 'spec/mocks/argument_constraint_matchers'
require 'spec/mocks/spec_methods'
require 'spec/mocks/proxy'
require 'spec/mocks/mock'
require 'spec/mocks/argument_expectation'
require 'spec/mocks/message_expectation'
require 'spec/mocks/order_group'
require 'spec/mocks/errors'
require 'spec/mocks/error_generator'
require 'spec/mocks/extensions/object'
require 'spec/mocks/space'

module Spec
  # == Mocks and Stubs
  #
  # RSpec will create Mock Objects and Stubs for you at runtime, or attach stub/mock behaviour
  # to any of your real objects (Partial Mock/Stub). Because the underlying implementation
  # for mocks and stubs is the same, you can intermingle mock and stub
  # behaviour in either dynamically generated mocks or your pre-existing classes.
  # There is a semantic difference in how they are created, however,
  # which can help clarify the role it is playing within a given spec.
  #
  # == Mock Objects
  # 
  # Mocks are objects that allow you to set and verify expectations that they will
  # receive specific messages during run time. They are very useful for specifying how the subject of
  # the spec interacts with its collaborators. This approach is widely known as "interaction
  # testing".
  # 
  # Mocks are also very powerful as a design tool. As you are
  # driving the implementation of a given class, Mocks provide an anonymous
  # collaborator that can change in behaviour as quickly as you can write an expectation in your
  # spec. This flexibility allows you to design the interface of a collaborator that often
  # does not yet exist. As the shape of the class being specified becomes more clear, so do the
  # requirements for its collaborators - often leading to the discovery of new types that are
  # needed in your system.
  # 
  # Read Endo-Testing[http://www.mockobjects.com/files/endotesting.pdf] for a much
  # more in depth description of this process.
  # 
  # == Stubs
  # 
  # Stubs are objects that allow you to set "stub" responses to
  # messages. As Martin Fowler points out on his site,
  # mocks_arent_stubs[http://www.martinfowler.com/articles/mocksArentStubs.html].
  # Paraphrasing Fowler's paraphrasing
  # of Gerard Meszaros: Stubs provide canned responses to messages they might receive in a test, while
  # mocks allow you to specify and, subsquently, verify that certain messages should be received during
  # the execution of a test.
  # 
  # == Partial Mocks/Stubs
  # 
  # RSpec also supports partial mocking/stubbing, allowing you to add stub/mock behaviour
  # to instances of your existing classes. This is generally
  # something to be avoided, because changes to the class can have ripple effects on
  # seemingly unrelated specs. When specs fail due to these ripple effects, the fact
  # that some methods are being mocked can make it difficult to understand why a
  # failure is occurring.
  # 
  # That said, partials do allow you to expect and
  # verify interactions with class methods such as +#find+ and +#create+
  # on Ruby on Rails model classes.
  # 
  # == Further Reading
  # 
  # There are many different viewpoints about the meaning of mocks and stubs. If you are interested
  # in learning more, here is some recommended reading:
  # 
  # * Mock Objects: http://www.mockobjects.com/
  # * Endo-Testing: http://www.mockobjects.com/files/endotesting.pdf
  # * Mock Roles, Not Objects: http://www.mockobjects.com/files/mockrolesnotobjects.pdf
  # * Test Double Patterns: http://xunitpatterns.com/Test%20Double%20Patterns.html
  # * Mocks aren't stubs: http://www.martinfowler.com/articles/mocksArentStubs.html
  #
  # == Creating a Mock
  #
  # You can create a mock in any specification (or setup) using:
  #
  #   mock(name, options={})
  #
  # The optional +options+ argument is a +Hash+. Currently the only supported
  # option is +:null_object+. Setting this to true instructs the mock to ignore
  # any messages it hasn’t been told to expect – and quietly return itself. For example:
  #
  #   mock("person", :null_object => true)
  #
  # == Creating a Stub
  #
  # You can create a stub in any specification (or setup) using:
  #
  #   stub(name, stub_methods_and_values_hash)
  #
  # For example, if you wanted to create an object that always returns
  # "More?!?!?!" to "please_sir_may_i_have_some_more" you would do this:
  #
  #   stub("Mr Sykes", :please_sir_may_i_have_some_more => "More?!?!?!")
  #
  # == Creating a Partial Mock
  #
  # You don't really "create" a partial mock, you simply add method stubs and/or
  # mock expectations to existing classes and objects:
  #
  #   Factory.should_receive(:find).with(id).and_return(value)
  #   obj.stub!(:to_i).and_return(3)
  #   etc ...
  #
  # == Expecting Messages
  #
  #   my_mock.should_receive(:sym)
  #   my_mock.should_not_receive(:sym)
  #   
  # == Expecting Arguments
  #
  #   my_mock.should_receive(:sym).with(*args)
  #   my_mock.should_not_receive(:sym).with(*args)
  #
  # == Argument Constraints using Expression Matchers
  #
  # Arguments that are passed to #with are compared with actual arguments received
  # using == by default. In cases in which you want to specify things about the arguments
  # rather than the arguments themselves, you can use any of the Expression Matchers.
  # They don't all make syntactic sense (they were primarily designed for use with
  # Spec::Expectations), but you are free to create your own custom Spec::Matchers.
  #
  # Spec::Mocks does provide one additional Matcher method named #ducktype.
  #
  # In addition, Spec::Mocks adds some keyword Symbols that you can use to
  # specify certain kinds of arguments:
  #
  #   my_mock.should_receive(:sym).with(no_args())
  #   my_mock.should_receive(:sym).with(any_args())
  #   my_mock.should_receive(:sym).with(1, an_instance_of(Numeric), "b") #2nd argument can any type of Numeric
  #   my_mock.should_receive(:sym).with(1, boolean(), "b") #2nd argument can true or false
  #   my_mock.should_receive(:sym).with(1, /abc/, "b") #2nd argument can be any String matching the submitted Regexp
  #   my_mock.should_receive(:sym).with(1, anything(), "b") #2nd argument can be anything at all
  #   my_mock.should_receive(:sym).with(1, ducktype(:abs, :div), "b")
  #                            #2nd argument can be object that responds to #abs and #div
  #                                                                       
  # == Receive Counts
  #
  #   my_mock.should_receive(:sym).once
  #   my_mock.should_receive(:sym).twice
  #   my_mock.should_receive(:sym).exactly(n).times
  #   my_mock.should_receive(:sym).at_least(:once)
  #   my_mock.should_receive(:sym).at_least(:twice)
  #   my_mock.should_receive(:sym).at_least(n).times
  #   my_mock.should_receive(:sym).at_most(:once)
  #   my_mock.should_receive(:sym).at_most(:twice)
  #   my_mock.should_receive(:sym).at_most(n).times
  #   my_mock.should_receive(:sym).any_number_of_times
  #
  # == Ordering
  #
  #   my_mock.should_receive(:sym).ordered
  #   my_mock.should_receive(:other_sym).ordered
  #     #This will fail if the messages are received out of order
  #
  # == Setting Reponses
  #
  # Whether you are setting a mock expectation or a simple stub, you can tell the
  # object precisely how to respond:
  #
  #   my_mock.should_receive(:sym).and_return(value)
  #   my_mock.should_receive(:sym).exactly(3).times.and_return(value1, value2, value3)
  #     # returns value1 the first time, value2 the second, etc
  #   my_mock.should_receive(:sym).and_return { ... } #returns value returned by the block
  #   my_mock.should_receive(:sym).and_raise(error)
  #     #error can be an instantiated object or a class
  #     #if it is a class, it must be instantiable with no args
  #   my_mock.should_receive(:sym).and_throw(:sym)
  #   my_mock.should_receive(:sym).and_yield(values,to,yield)
  #   my_mock.should_receive(:sym).and_yield(values,to,yield).and_yield(some,other,values,this,time)
  #     # for methods that yield to a block multiple times
  #
  # Any of these responses can be applied to a stub as well, but stubs do
  # not support any qualifiers about the message received (i.e. you can't specify arguments
  # or receive counts):
  #
  #   my_mock.stub!(:sym).and_return(value)
  #   my_mock.stub!(:sym).and_return(value1, value2, value3)
  #   my_mock.stub!(:sym).and_raise(error)
  #   my_mock.stub!(:sym).and_throw(:sym)
  #   my_mock.stub!(:sym).and_yield(values,to,yield)
  #   my_mock.stub!(:sym).and_yield(values,to,yield).and_yield(some,other,values,this,time)
  #
  # == Arbitrary Handling
  #
  # Once in a while you'll find that the available expectations don't solve the
  # particular problem you are trying to solve. Imagine that you expect the message
  # to come with an Array argument that has a specific length, but you don't care
  # what is in it. You could do this:
  #
  #   my_mock.should_receive(:sym) do |arg|
  #     arg.should be_an_istance_of(Array)
  #     arg.length.should == 7
  #   end
  #
  # Note that this would fail if the number of arguments received was different from
  # the number of block arguments (in this case 1).
  #
  # == Combining Expectation Details
  #
  # Combining the message name with specific arguments, receive counts and responses
  # you can get quite a bit of detail in your expectations:
  #
  #   my_mock.should_receive(:<<).with("illegal value").once.and_raise(ArgumentError)
  module Mocks
  end
end
