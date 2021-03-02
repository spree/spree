require 'spec_helper'

describe Spree::ServiceModule do
  context 'noncallable thing passed to run' do
    class ServiceObjectWithUncallableThing
      prepend ::Spree::ServiceModule::Base

      def call
        run 'something_crazy'
      end
    end

    let(:result) { ServiceObjectWithUncallableThing.new.call }

    it 'raises NonCallablePassedToRun' do
      expect { result }.to raise_error(Spree::ServiceModule::NonCallablePassedToRun)
    end
  end

  context 'unimplemented method' do
    class ServiceObjectWithMissingMethod
      prepend ::Spree::ServiceModule::Base

      def call
        run :non_existing_method
      end
    end

    let(:result) { ServiceObjectWithMissingMethod.new.call }

    it 'raises MethodNotImplemented' do
      expect { result }.to raise_error(Spree::ServiceModule::MethodNotImplemented)
    end

    it 'returns message in exception' do
      begin
        result
      rescue Spree::ServiceModule::MethodNotImplemented => e
        expect(e.message).to eq("You didn't implement non_existing_method method. Implement it before calling this class")
      end
    end
  end

  context 'non wrapped value' do
    class ServiceObjectWithNonWrappedReturn
      prepend ::Spree::ServiceModule::Base

      def call
        run :first_method
        run :second_method
      end

      private

      def first_method
        'not wrapped return'
      end

      def second_method; end
    end

    it 'raises WrongDataPassed' do
      expect { ServiceObjectWithNonWrappedReturn.new.call }.to raise_error(Spree::ServiceModule::WrongDataPassed)
    end

    it 'returns message in exception' do
      begin
        ServiceObjectWithNonWrappedReturn.new.call
      rescue Spree::ServiceModule::WrongDataPassed => e
        expect(e.message).to eq("You didn't use `success` or `failure` method to return value from method.")
      end
    end
  end

  context 'non wrapped value in last method' do
    class ServiceObjectWithNonWrappedReturn
      prepend ::Spree::ServiceModule::Base

      def call
        run :first_method
      end

      private

      def first_method
        'not wrapped return'
      end
    end

    it 'raises WrongDataPassed' do
      expect { ServiceObjectWithNonWrappedReturn.new.call }.to raise_error(Spree::ServiceModule::WrongDataPassed)
    end
  end

  context 'first method failed' do
    class ServiceObjectWithFailure
      prepend ::Spree::ServiceModule::Base

      def call
        run :first_method
        run :second_method
      end

      private

      def first_method
        failure('Failed!')
      end

      def second_method
        success('Success!')
      end
    end

    let(:service) { ServiceObjectWithFailure.new }
    let(:result) { service.call }

    it 'returns result with success? false' do
      expect(result.success?).to eq(false)
    end

    it 'returns result with failure? true' do
      expect(result.failure?).to eq(true)
    end

    it 'returns value from first failed method' do
      expect(result.value).to eq('Failed!')
    end

    it 'returns result which is instance of Result' do
      expect(result).to be_an_instance_of(Spree::ServiceModule::Result)
    end

    it "doesn't call second method" do
      expect(service).not_to receive(:second_method)
      service.call
    end
  end

  context 'success' do
    class ServiceObjectWithSuccess
      prepend ::Spree::ServiceModule::Base

      def call(params: {})
        run :first_method
        run :second_method
      end

      private

      def first_method(params:)
        success(params: 'First Method Success!')
      end

      def second_method(params:)
        success(params + ' Second Method Success!')
      end
    end

    let(:service) { ServiceObjectWithSuccess.new }
    let(:result) { service.call(params: {}) }

    it 'returns result with success? true' do
      expect(result.success?).to eq(true)
    end

    it 'returns result with failure? false' do
      expect(result.failure?).to eq(false)
    end

    it 'returns value from last method' do
      expect(result.value).to include('Second Method Success!')
      expect(result.value).to include('First Method Success!')
    end

    it 'calls second method' do
      skip_if_ruby_3
      expect(service).to receive(:second_method).and_call_original
      service.call(params: {})
    end

    it 'passes input from call to first run method' do
      skip_if_ruby_3
      param = 'param'
      expect(service).to receive(:first_method).with(params: param).and_call_original
      service.call(params: param)
    end

    it 'passes empty hash if input was not provided' do
      skip_if_ruby_3
      expect(service).to receive(:first_method).with(params: {}).and_call_original
      service.call(params: {})
    end

    # FIXME: https://github.com/rspec/rspec-mocks/issues/1306
    def skip_if_ruby_3
      skip 'https://github.com/rspec/rspec-mocks/issues/1306' if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    end
  end

  context 'not compatible params passed as result' do
    class ServiceObjectWithIncompatibleParams
      prepend ::Spree::ServiceModule::Base

      def call
        run :first_method
        run :second_method
      end

      private

      def first_method
        success(first_value: 'asd', second_value: 'qwe')
      end

      def second_method(first_value:)
        success(first_value + ' Second Method Success!')
      end
    end

    let(:service) { ServiceObjectWithIncompatibleParams.new }

    it 'raises exception' do
      expect { service.call }.to raise_error(Spree::ServiceModule::IncompatibleParamsPassed)
    end
  end
end
