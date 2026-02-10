require 'spec_helper'

describe Spree::Core::TokenGenerator do
  class DummyClass
    include Spree::Core::TokenGenerator

    attr_reader :created_at

    def initialize
      @created_at = Time.now.to_i
    end
  end

  let(:dummy_class_instance) { DummyClass.new }

  describe 'generate_token' do
    let(:generated_token) { dummy_class_instance.generate_token }

    it 'generates random token with timestamp' do
      expect(generated_token.size).to eq 35
      expect(generated_token).to include dummy_class_instance.created_at.to_s
    end
  end
end
