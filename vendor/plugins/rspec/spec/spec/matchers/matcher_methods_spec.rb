require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Matchers
    context %Q{The Spec::Matchers module gets included in the execution context of every spec.
This module should provide the following methods, each of which returns a Matcher object.} do
      it "be_true" do
        be_true.should be_an_instance_of(Be)
      end
      it "be_false" do
        be_false.should be_an_instance_of(Be)
      end
      it "be_nil" do
        be_nil.should be_an_instance_of(Be)
      end
      it "be_arbitrary_predicate" do
        be_arbitrary_predicate.should be_an_instance_of(Be)
      end
      it "be_close" do
        be_close(1,2).should be_an_instance_of(BeClose)
      end
      it "change" do
        change("target", :message).should be_an_instance_of(Change)
      end
      it "eql" do
        eql(:expected).should be_an_instance_of(Eql)
      end
      it "equal" do
        equal(:expected).should be_an_instance_of(Equal)
      end
      it "have" do
        have(0).should be_an_instance_of(Have)
      end
      it "have_exactly" do
        have_exactly(0).should be_an_instance_of(Have)
      end
      it "have_at_least" do
        have_at_least(0).should be_an_instance_of(Have)
      end
      it "have_at_most" do
        have_at_most(0).should be_an_instance_of(Have)
      end
      it "include" do
        include(:value).should be_an_instance_of(Include)
      end
      it "match" do
        match(:value).should be_an_instance_of(Match)
      end
      it "raise_error" do
        raise_error.should be_an_instance_of(RaiseError)
        raise_error(NoMethodError).should be_an_instance_of(RaiseError)
        raise_error(NoMethodError, "message").should be_an_instance_of(RaiseError)
      end
      it "satisfy" do
        satisfy{}.should be_an_instance_of(Satisfy)
      end
      it "throw_symbol" do
        throw_symbol.should be_an_instance_of(ThrowSymbol)
        throw_symbol(:sym).should be_an_instance_of(ThrowSymbol)
      end
      it "respond_to" do
        respond_to(:sym).should be_an_instance_of(RespondTo)
      end
    end
    
    describe "Spec::Matchers#method_missing" do
      it "should convert be_xyz to Be(:be_xyz)" do
        Be.should_receive(:new).with(:be_whatever)
        be_whatever
      end

      it "should convert have_xyz to Has(:have_xyz)" do
        Has.should_receive(:new).with(:have_whatever)
        have_whatever
      end
    end
  end
end
