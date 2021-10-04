require 'spec_helper'

module Test
  class Product < ActiveRecord::Base
    self.table_name = 'test_products'

    validates :url, :'spree/webhooks/validators/url' => true
  end
end

describe Spree::Webhooks::Validators::UrlValidator do
  before(:all) do
    ActiveRecord::Base.connection.create_table :test_products, force: true do |t|
      t.string :url
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :test_products, if_exists: true
  end

  describe 'validating the given URL' do
    context 'is invalid' do
      it { expect(Test::Product.new(url: nil).valid?).to eq(false) }
      it { expect(Test::Product.new(url: 'google.com').valid?).to eq(false) }
      it { expect(Test::Product.new(url: 'http:/google').valid?).to eq(false) }
      it { expect(Test::Product.new(url: 'www.google.com').valid?).to eq(false) }
    end

    context 'is valid' do
      it { expect(Test::Product.new(url: 'http://google.com').valid?).to eq(true) }
      it { expect(Test::Product.new(url: 'https://google.com').valid?).to eq(true) }
      it { expect(Test::Product.new(url: 'http://www.google.com').valid?).to eq(true) }
      it { expect(Test::Product.new(url: 'https://www.google.com').valid?).to eq(true) }
      # Due to simplicity, this is valid even without tld
      it { expect(Test::Product.new(url: 'http://google').valid?).to eq(true) }
    end
  end

  describe 'using a given message or a defined one' do
    let(:test_product) { Test::Product.new(url: nil) }

    context 'using the message option' do
      let(:message) { 'is needed' }

      it 'adds the given message to the record url errors array' do
        # Remove the validation set at the beginning
        Test::Product.clear_validators!
        Test::Product.validates(:url, :'spree/webhooks/validators/url' => { message: message })

        test_product.valid?
        expect(test_product.errors.messages).to eq(url: [message])

        # Add back the validation removed previously
        Test::Product.clear_validators!
        Test::Product.validates(:url, :'spree/webhooks/validators/url' => true)
      end
    end

    context 'without using the message option' do
      it 'adds a pre-defined message to the record url error array' do
        test_product.valid?
        expect(test_product.errors.messages).to eq(url: ['must be a valid URL'])
      end
    end
  end
end
