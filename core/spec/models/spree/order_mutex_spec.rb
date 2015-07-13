require 'spec_helper'

describe Spree::OrderMutex do
  let(:order) { create(:order) }

  context "without an existing lock" do
    it "executes the block" do
      calls = 0
      Spree::OrderMutex.with_lock!(order) { calls += 1 }
      expect(calls).to eq 1
    end

    it "releases the lock for subsequent calls" do
      calls = 0
      Spree::OrderMutex.with_lock!(order) { calls += 1 }
      Spree::OrderMutex.with_lock!(order) { calls += 1 }
      expect(calls).to eq 2
    end

    it "returns the value of the block" do
      expect(Spree::OrderMutex.with_lock!(order) { 'yay for spree' }).to eq 'yay for spree'
    end
  end

  context "with an existing lock on the same order" do
    it "raises a LockFailed error and then releases the lock" do
      expect {
        Spree::OrderMutex.with_lock!(order) do
          Spree::OrderMutex.with_lock!(order) { }
        end
      }.to raise_error(Spree::OrderMutex::LockFailed)

      expect {
        Spree::OrderMutex.with_lock!(order) { }
      }.to_not raise_error
    end
  end

  context "with an expired existing lock on the same order" do
    around do |example|
      Spree::OrderMutex.with_lock!(order) do
        future = Spree::Config[:order_mutex_max_age].from_now + 1.second
        Timecop.freeze(future) do
          example.run
        end
      end
    end

    it "executes the block" do
      calls = 0
      Spree::OrderMutex.with_lock!(order) { calls += 1 }
      expect(calls).to eq 1
    end
  end

  context "with an existing lock on a different order" do
    let(:order2) { create(:order) }

    around do |example|
      Spree::OrderMutex.with_lock!(order2) { example.run }
    end

    it "executes the block" do
      calls = 0
      Spree::OrderMutex.with_lock!(order) { calls += 1 }
      expect(calls).to eq 1
    end
  end
end
