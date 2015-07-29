require 'spec_helper'

describe Spree::Api::Responders::RablTemplate do
  subject { described_class.new(controller, [resource], options) }

  let(:controller) { instance_double(Spree::Api::BaseController) }
  let(:resource)   { double('resource')                          }
  let(:options)    { {}                                          }

  let(:described_class) do
    Class.new(ActionController::Responder) do
      include Spree::Api::Responders::RablTemplate
    end
  end

  describe '#to_format' do
    let(:request)  { double('request')  }
    let(:response) { double('response') }

    before do
      allow(controller).to receive_messages(
        request: request,
        render:  response,
        formats: []
      )
    end

    context 'when the template is specified' do
      let(:options) { super().merge(default_template: :show) }

      context 'when the status is specified' do
        let(:options) { super().merge(status: :created) }

        it 'renders the template with the sepcified status' do
          expect(controller).to receive(:render)
            .with(:show, status: :created).and_return(response)
          expect(subject.to_format).to be(response)
        end
      end

      context 'when the status is not specified' do
        it 'renders the template with the default status' do
          expect(controller).to receive(:render)
            .with(:show, status: :ok).and_return(response)
          expect(subject.to_format).to be(response)
        end
      end
    end

    context 'when the template is not specified' do
      it 'calls super' do
        expect_any_instance_of(described_class.superclass)
          .to receive(:to_format).and_return(response)
        expect(subject.to_format).to be(response)
      end
    end
  end
end
