import { runAcceptanceSpec } from '../lib/project.mjs'

// A local listener stands in for the external service, so the check holds
// whichever HTTP client the agent picks.
//
// The starter sets Solid Queue as the job adapter for every environment, and
// ActiveJob::TestHelper keeps an adapter the app configured, so jobs would
// land in the queue tables and perform_enqueued_jobs would run none of them.
// The spec switches to the test adapter itself.
const SPEC = `require 'rails_helper'
require 'socket'

RSpec.describe 'Agent benchmark: order sync', type: :model do
  include ActiveJob::TestHelper

  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:requests) { Queue.new }

  before do
    WebMock.allow_net_connect! if defined?(WebMock)
    port = server.addr[1]
    Thread.new do
      loop do
        client = server.accept
        head = +''
        head << client.readpartial(4096) until head.include?("\\r\\n\\r\\n")
        header, body = head.split("\\r\\n\\r\\n", 2)
        length = header[/content-length:\\s*(\\d+)/i, 1].to_i
        body << client.readpartial(4096) while body.bytesize < length
        requests << { request_line: header.lines.first, body: body }
        client.write("HTTP/1.1 200 OK\\r\\nContent-Length: 2\\r\\nConnection: close\\r\\n\\r\\n{}")
        client.close
      end
    rescue IOError
      # The server closed after the example.
    end
    stub_const('ENV', ENV.to_h.merge('ORDER_SYNC_URL' => "http://127.0.0.1:#{port}/orders"))
  end

  after { server.close }

  it 'posts a placed order to ORDER_SYNC_URL' do
    order = create(:completed_order_with_totals)

    Spree::Events.enable do
      Spree::Events.activate!
      perform_enqueued_jobs { order.publish_event('order.placed') }
    end

    request = Timeout.timeout(10) { requests.pop }
    expect(request[:request_line]).to start_with('POST /orders')
    payload = JSON.parse(request[:body])
    expect(payload['id']).to eq(order.prefixed_id)
    expect(payload['number']).to eq(order.number)
    expect(BigDecimal(payload['total'].to_s)).to eq(order.total)
    expect(payload['currency']).to eq(order.currency)
    expect(requests).to be_empty
  end
end
`

export default {
  id: 'order-sync-subscriber',
  title: 'Sync placed orders to an external service',
  project: { storefront: false },
  timeoutMinutes: 30,
  prompt: `Our fulfilment partner needs to hear about every order the moment it is placed.

When an order is placed, send an HTTP POST to the URL in the ORDER_SYNC_URL environment variable, with a JSON body like:

  {"id": "<the order's public id>", "number": "<order number>", "total": "<order total as a decimal string>", "currency": "<currency code>"}

Send exactly one request per placed order. Placing the order must not fail if the partner is down. Add a spec for it, and make sure the change is live in the running app.`,
  check: ({ projectDir }) => runAcceptanceSpec(projectDir, 'order_sync', SPEC),
}
