module Spec
  module Mocks
    module ExampleMethods
      include Spec::Mocks::ArgumentConstraintMatchers

      # Shortcut for creating an instance of Spec::Mocks::Mock.
      #
      # +name+ is used for failure reporting, so you should use the
      # role that the mock is playing in the example.
      #
      # +stubs_and_options+ lets you assign options and stub values
      # at the same time. The only option available is :null_object.
      # Anything else is treated as a stub value.
      #
      # == Examples
      #
      #   stub_thing = mock("thing", :a => "A")
      #   stub_thing.a == "A" => true
      #
      #   stub_person = stub("thing", :name => "Joe", :email => "joe@domain.com")
      #   stub_person.name => "Joe"
      #   stub_person.email => "joe@domain.com"
      def mock(name, stubs_and_options={})
        Spec::Mocks::Mock.new(name, stubs_and_options)
      end
      
      alias :stub :mock

      # Shortcut for creating a mock object that will return itself in response
      # to any message it receives that it hasn't been explicitly instructed
      # to respond to.
      def stub_everything(name = 'stub')
        mock(name, :null_object => true)
      end

    end
  end
end
