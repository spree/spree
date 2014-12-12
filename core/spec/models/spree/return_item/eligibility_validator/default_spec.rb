require 'spec_helper'

describe Spree::ReturnItem::EligibilityValidator::Default, :type => :model do
  let(:return_item) { create(:return_item) }
  let(:validator) { Spree::ReturnItem::EligibilityValidator::Default.new(return_item) }

  let(:time_eligibility_class) { double("TimeEligibilityValidatorClass") }
  let(:rma_eligibility_class)  { double("RMAEligibilityValidatorClass") }

  let(:time_eligibility_instance) { double(errors: time_error) }
  let(:rma_eligibility_instance)  { double(errors: rma_error) }

  let(:time_error) {{}}
  let(:rma_error)  {{}}

  before do
    validator.permitted_eligibility_validators = [ time_eligibility_class, rma_eligibility_class ]

    expect(time_eligibility_class).to receive(:new).and_return(time_eligibility_instance)
    expect(rma_eligibility_class).to receive(:new).and_return(rma_eligibility_instance)
  end

  describe "#eligible_for_return?" do
    subject { validator.eligible_for_return? }

    it "checks that all permitted eligibility validators are eligible for return" do
      expect(time_eligibility_instance).to receive(:eligible_for_return?).and_return(true)
      expect(rma_eligibility_instance).to receive(:eligible_for_return?).and_return(true)

      expect(subject).to be true
    end
  end

  describe "#requires_manual_intervention?" do
    subject { validator.requires_manual_intervention? }

    context "any of the permitted eligibility validators require manual intervention" do
      it "returns true" do
        expect(time_eligibility_instance).to receive(:requires_manual_intervention?).and_return(false)
        expect(rma_eligibility_instance).to receive(:requires_manual_intervention?).and_return(true)

        expect(subject).to be true
      end
    end

    context "no permitted eligibility validators require manual intervention" do
      it "returns false" do
        expect(time_eligibility_instance).to receive(:requires_manual_intervention?).and_return(false)
        expect(rma_eligibility_instance).to receive(:requires_manual_intervention?).and_return(false)

        expect(subject).to be false
      end
    end
  end

  describe "#errors" do
    subject { validator.errors }

    context "the validator errors are empty" do
      it "returns an empty hash" do
        expect(subject).to eq({})
      end
    end

    context "the validators have errors" do
      let(:time_error) { { time: time_error_text }}
      let(:rma_error)  { { rma: rma_error_text }}

      let(:time_error_text) { "Time eligibility error" }
      let(:rma_error_text)  { "RMA eligibility error" }

      it "gathers all errors from permitted eligibility validators into a single errors hash" do
        expect(subject).to eq({time: time_error_text, rma: rma_error_text})
      end
    end
  end
end
