require 'spec_helper'

describe Spree::ReturnItem::DefaultEligibilityValidator do
  let(:return_item) { create(:return_item) }
  let(:validator) { Spree::ReturnItem::DefaultEligibilityValidator.new(return_item) }

  let(:time_eligibility_class) { double("TimeEligibilityValidatorClass") }
  let(:rma_eligibility_class)  { double("RMAEligibilityValidatorClass") }

  let(:time_eligibility_instance) { double(errors: time_error) }
  let(:rma_eligibility_instance)  { double(errors: rma_error) }

  let(:time_error) {{}}
  let(:rma_error)  {{}}

  before do
    validator.permitted_eligibility_validators = [ time_eligibility_class, rma_eligibility_class ]

    time_eligibility_class.should_receive(:new).and_return(time_eligibility_instance)
    rma_eligibility_class.should_receive(:new).and_return(rma_eligibility_instance)
  end

  describe "#eligible_for_return?" do
    subject { validator.eligible_for_return? }

    it "checks that all permitted eligibility validators are eligible for return" do
      time_eligibility_instance.should_receive(:eligible_for_return?).and_return(true)
      rma_eligibility_instance.should_receive(:eligible_for_return?).and_return(true)

      subject.should be true
    end
  end

  describe "#requires_manual_intervention?" do
    subject { validator.requires_manual_intervention? }

    context "any of the permitted eligibility validators require manual intervention" do
      it "returns true" do
        time_eligibility_instance.should_receive(:requires_manual_intervention?).and_return(false)
        rma_eligibility_instance.should_receive(:requires_manual_intervention?).and_return(true)

        subject.should be true
      end
    end

    context "no permitted eligibility validators require manual intervention" do
      it "returns false" do
        time_eligibility_instance.should_receive(:requires_manual_intervention?).and_return(false)
        rma_eligibility_instance.should_receive(:requires_manual_intervention?).and_return(false)

        subject.should be false
      end
    end
  end

  describe "#errors" do
    subject { validator.errors }

    context "the validator errors are empty" do
      it "returns an empty hash" do
        subject.should == {}
      end
    end

    context "the validators have errors" do
      let(:time_error) { { time: time_error_text }}
      let(:rma_error)  { { rma: rma_error_text }}

      let(:time_error_text) { "Time eligibility error" }
      let(:rma_error_text)  { "RMA eligibility error" }

      it "gathers all errors from permitted eligibility validators into a single errors hash" do
        subject.should == {time: time_error_text, rma: rma_error_text}
      end
    end
  end
end
