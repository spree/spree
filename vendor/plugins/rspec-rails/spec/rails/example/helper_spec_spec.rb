require File.dirname(__FILE__) + '/../../spec_helper'
Spec::Runner.configuration.global_fixtures = :people

describe ExplicitHelper, :type => :helper do
  include ExplicitHelper
  
  it "should not require naming the helper if describe is passed a type" do
    method_in_explicit_helper.should match(/text from a method/)
    helper.method_in_explicit_helper.should match(/text from a method/)
  end
end

module Spec
  module Rails
    module Example
      describe HelperExampleGroup, :type => :helper do
        helper_name :explicit

        it "DEPRECATED should have direct access to methods defined in helpers" do
          method_in_explicit_helper.should =~ /text from a method/
        end

        it "should expose the helper with the #helper method" do
          helper.method_in_explicit_helper.should =~ /text from a method/
        end

        it "should have access to named routes" do
          rspec_on_rails_specs_url.should == "http://test.host/rspec_on_rails_specs"
          rspec_on_rails_specs_path.should == "/rspec_on_rails_specs"

          helper.named_url.should == "http://test.host/rspec_on_rails_specs"
          helper.named_path.should == "/rspec_on_rails_specs"
        end

        it "should fail if the helper method deson't exist" do
          lambda { non_existent_helper_method }.should raise_error(NameError)
          lambda { helper.non_existent_helper_method }.should raise_error(NameError)
        end

        it "should have access to session" do
          session[:foo] = 'bar'
          session_foo.should == 'bar'
          helper.session_foo.should == 'bar'
        end
        
        it "should have access to params" do
          params[:foo] = 'bar'
          params_foo.should == 'bar'
          helper.params_foo.should == 'bar'
        end
        
        it "should have access to request" do
          request.stub!(:thing).and_return('bar')
          request_thing.should == 'bar'
          helper.request_thing.should == 'bar'
        end
        
        it "should have access to flash" do
          flash[:thing] = 'camera'
          flash_thing.should == 'camera'
          helper.flash_thing.should == 'camera'
        end
      end

      describe HelperExampleGroup, "#eval_erb", :type => :helper do
        helper_name :explicit

        it "should support methods that accept blocks" do
          eval_erb("<% prepend 'foo' do %>bar<% end %>").should == "foobar"
        end
      end

      describe HelperExampleGroup, ".fixtures", :type => :helper do
        helper_name :explicit
        fixtures :animals

        it "should load fixtures" do
          pig = animals(:pig)
          pig.class.should == Animal
        end

        it "should load global fixtures" do
          lachie = people(:lachie)
          lachie.class.should == Person
        end
      end
      
      describe "methods from standard helpers", :type => :helper do
        helper_name :explicit
        it "should be exposed to the helper" do
          helper.link_to("Foo","http://bar").should have_tag("a")
        end
      end

      describe HelperExampleGroup, "included modules", :type => :helper do
        helpers = [
          ActionView::Helpers::ActiveRecordHelper,
          ActionView::Helpers::AssetTagHelper,
          ActionView::Helpers::BenchmarkHelper,
          ActionView::Helpers::CacheHelper,
          ActionView::Helpers::CaptureHelper,
          ActionView::Helpers::DateHelper,
          ActionView::Helpers::DebugHelper,
          ActionView::Helpers::FormHelper,
          ActionView::Helpers::FormOptionsHelper,
          ActionView::Helpers::FormTagHelper,
          ActionView::Helpers::JavaScriptHelper,
          ActionView::Helpers::NumberHelper,
          ActionView::Helpers::PrototypeHelper,
          ActionView::Helpers::ScriptaculousHelper,
          ActionView::Helpers::TagHelper,
          ActionView::Helpers::TextHelper,
          ActionView::Helpers::UrlHelper
        ]
        helpers << ActionView::Helpers::PaginationHelper rescue nil       #removed for 2.0
        helpers << ActionView::Helpers::JavaScriptMacrosHelper rescue nil #removed for 2.0
        helpers.each do |helper_module|
          it "should include #{helper_module}" do
            self.class.ancestors.should include(helper_module)
            helper.class.ancestors.should include(helper_module)
          end
        end
      end
      
      # TODO: BT - Helper Examples should proxy method_missing to a Rails View instance.
      # When that is done, remove this method
      describe HelperExampleGroup, "#protect_against_forgery?", :type => :helper do
        it "should return false" do
          protect_against_forgery?.should be_false
          helper.protect_against_forgery?.should be_false
        end
      end
    end
  end
end

module Bug11223
  # see http://rubyforge.org/tracker/index.php?func=detail&aid=11223&group_id=797&atid=3149
  describe 'Accessing flash from helper spec', :type => :helper do
    it 'should not raise an error' do
      lambda { flash['test'] }.should_not raise_error
    end
  end
end

module Spec
  module Rails
    module Example
      describe HelperExampleGroup do
        it "should clear its name from the description" do
          group = describe("foo", :type => :helper) do
            $nested_group = describe("bar") do
            end
          end
          group.description.to_s.should == "foo"
          $nested_group.description.to_s.should == "foo bar"
        end
      end
    end
  end
end
