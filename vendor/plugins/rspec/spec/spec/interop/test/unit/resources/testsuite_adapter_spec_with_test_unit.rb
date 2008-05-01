rspec_lib = File.dirname(__FILE__) + "/../../../../../../lib"
$:.unshift rspec_lib unless $:.include?(rspec_lib)
require "test/unit"
require "spec"

module Test
  module Unit
    describe TestSuiteAdapter do
      def create_adapter(group)
        TestSuiteAdapter.new(group)
      end

      describe "#size" do
        it "should return the number of examples in the example group" do
          group = Class.new(Spec::ExampleGroup) do
            describe("some examples")
            it("bar") {}
            it("baz") {}
          end
          adapter = create_adapter(group)
          adapter.size.should == 2
        end
      end

      describe "#delete" do
        it "should do nothing" do
          group = Class.new(Spec::ExampleGroup) do
            describe("Some Examples")
            it("does something") {}
          end
          adapter = create_adapter(group)
          adapter.delete(adapter.examples.first)
          adapter.should be_empty
        end
      end
    end
  end
end
