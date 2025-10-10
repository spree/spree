require 'spec_helper'

module Spree
  describe DisplayMoney do
    let(:test_instance) { test_class.new }
    let(:test_class) do
      Class.new do
        extend DisplayMoney
        def total
          10.0
        end
      end
    end

    describe '.money_methods' do
      before { test_class.money_methods :total }

      context 'currency is not defined' do
        it 'generates a display_method that builds a Spree::Money without options' do
          expect(test_instance.display_total).to eq Spree::Money.new(10.0)
        end

        context 'wrapped method accepts `:currency` keyword argument' do
          let(:test_class) do
            Class.new do
              extend DisplayMoney
              def total(currency:)
                10.0
              end
            end
          end
          let(:currency) { 'GBP' }

          it 'defined method passes the received keyword argument to the wrapped method' do
            expect(test_class.new.display_total(currency: currency)).to eq Spree::Money.new(10.0, currency: currency)
          end
        end

        context 'wrapped method accepts `currency` argument' do
          let(:test_class) do
            Class.new do
              extend DisplayMoney
              def total(currency)
                10.0
              end
            end
          end
          let(:currency) { 'GBP' }
          it 'defined method passes the received keyword argument to the wrapped method' do
            expect(test_class.new.display_total(currency: currency)).to eq Spree::Money.new(10.0, currency: currency)
          end
        end
      end

      context 'currency is defined' do
        before do
          test_class.class_eval do
            def currency
              'USD'
            end
          end
        end

        it 'generates a display_* method that builds a Spree::Money with currency' do
          expect(test_instance.display_total).to eq Spree::Money.new(10.0, currency: 'USD')
        end
      end

      context 'with multiple + options' do
        before do
          test_class.class_eval do
            def amount
              20.0
            end
          end
          test_class.money_methods :total, amount: { no_cents: true }
        end

        it 'generates a display_* method that builds a Spree::Money with the specified options' do
          expect(test_instance.display_total).to eq Spree::Money.new(10.0)
          expect(test_instance.display_amount).to eq Spree::Money.new(20.0, no_cents: true)
        end
      end
    end
  end
end
