require 'spec_helper'

describe Spree::Webhooks::Endpoints::MakeRequestJob, :job do
  let(:url) { 'http://url.com/' }
  let(:payload) { {} }

  it 'it enqueues a HTTP request using Spree::Webhooks::Endpoints::MakeRequest' do
    expect { described_class.perform_later(payload, url) }.to(
      have_enqueued_job.on_queue('spree_webhooks')
    )
  end
end
