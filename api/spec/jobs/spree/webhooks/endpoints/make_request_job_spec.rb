require 'spec_helper'

describe Spree::Webhooks::Endpoints::MakeRequestJob do
  let(:body) { {} }
  let(:event) { 'order.cancel' }
  let(:queue) { 'spree_webhooks' }
  let(:url) { 'http://url.com/' }

  it 'enqueues a HTTP request using Spree::Webhooks::Endpoints::MakeRequest', :job do
    expect { described_class.perform_later(body, event, url) }.to have_enqueued_job.on_queue(queue)
  end
end
