require 'spec_helper'

describe Spree::ServiceModule do
  context 'noncallable thing passed to run' do
    class ServiceObjectWithoutCall
      prepend ::Spree::ServiceModule::Base
    end

    it 'raises NonCallablePassedToRun' do
      expect { ServiceObjectWithoutCall.new.call }.to raise_error(Spree::ServiceModule::CallMethodNotImplemented)
    end
  end

  context 'noncallable thing passed to run' do
    class ServiceObjectWithUncallableThing
      prepend ::Spree::ServiceModule::Base

      def call(_params)
        run 'something_crazy'
      end
    end

    it 'raises NonCallablePassedToRun' do
      expect { ServiceObjectWithUncallableThing.new.call }.to raise_error(Spree::ServiceModule::NonCallablePassedToRun)
    end
  end

  context 'unimplemented method' do
    class ServiceObjectWithMissingMethod
      prepend ::Spree::ServiceModule::Base

      def call(_params)
        run :non_existing_method
      end
    end

    it 'raises MethodNotImplemented' do
      expect { ServiceObjectWithMissingMethod.new.call }.to raise_error(Spree::ServiceModule::MethodNotImplemented)
    end

    it 'returns message in exception' do
      begin
        ServiceObjectWithMissingMethod.new.call
      rescue Spree::ServiceModule::MethodNotImplemented => e
        expect(e.message).to eq("You didn't implement non_existing_method method. Implement it before calling this class")
      end
    end
  end

  context 'non wrapped value' do
    class ServiceObjectWithNonWrappedReturn
      prepend ::Spree::ServiceModule::Base

      def call(_params)
        run :first_method
        run :second_method
      end

      private

      def first_method(_params)
        'not wrapped return'
      end

      def second_method(params); end
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

      def call(_params)
        run :first_method
      end

      private

      def first_method(_params)
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

      def call(_params)
        run :first_method
        run :second_method
      end

      private

      def first_method(_params)
        failure('Failed!')
      end

      def second_method(_params)
        success('Success!')
      end
    end

    it 'returns result with success? false' do
      result = ServiceObjectWithFailure.new.call
      expect(result.success?).to eq(false)
    end

    it 'returns result with failure? true' do
      result = ServiceObjectWithFailure.new.call
      expect(result.failure?).to eq(true)
    end

    it 'returns value from first failed method' do
      result = ServiceObjectWithFailure.new.call
      expect(result.value).to eq('Failed!')
    end

    it 'returns result which is instance of Result' do
      result = ServiceObjectWithFailure.new.call
      expect(result).to be_an_instance_of(Spree::ServiceModule::Result)
    end

    it "doesn't call second method" do
      service = ServiceObjectWithFailure.new
      expect(service).not_to receive(:second_method)
      service.call
    end

    it 'returns Result instance' do
      expect(ServiceObjectWithFailure.new.call).to be_an_instance_of(Spree::ServiceModule::Result)
    end
  end

  context 'success' do
    class ServiceObjectWithSuccess
      prepend ::Spree::ServiceModule::Base

      def call(_params)
        run :first_method
        run :second_method
      end

      private

      def first_method(_params)
        success('First Method Success!')
      end

      def second_method(params)
        success(params + ' Second Method Success!')
      end
    end

    it 'returns result with success? true' do
      result = ServiceObjectWithSuccess.new.call
      expect(result.success?).to eq(true)
    end

    it 'returns result with failure? false' do
      result = ServiceObjectWithSuccess.new.call
      expect(result.failure?).to eq(false)
    end

    it 'returns value from last method' do
      result = ServiceObjectWithSuccess.new.call
      expect(result.value).to include('Second Method Success!')
      expect(result.value).to include('First Method Success!')
    end

    it 'calls second method' do
      service = ServiceObjectWithSuccess.new
      expect(service).to receive(:second_method).and_call_original
      service.call
    end

    it 'passes input from call to first run method' do
      param = 'param'
      service = ServiceObjectWithSuccess.new
      expect(service).to receive(:first_method).with(param).and_call_original
      service.call(param)
    end

    it 'passes empty hash if input was not provided' do
      service = ServiceObjectWithSuccess.new
      expect(service).to receive(:first_method).with({}).and_call_original
      service.call
    end
  end
end
