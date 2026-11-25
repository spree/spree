require 'spec_helper'

RSpec.describe Spree::Images::SaveFromUrlJob, type: :job do
  let!(:variant) { create(:variant) }
  let(:external_url) { "https://cdn.example.com/foo/Bar_Image.png" }
  let(:position) { nil }
  let(:external_id) { nil }
  let(:viewable_id) { variant.id }
  let(:viewable_type) { 'Spree::Variant' }
  let(:queue_name) { Spree.queues.images }

  subject(:job) { described_class.new(viewable_id, viewable_type, external_url, external_id, position).perform_now }

  it "is queued in the correct queue" do
    expect(described_class.queue_name).to eq(queue_name.to_s)
  end

  it "can be enqueued" do
    expect {
      described_class.perform_later(viewable_id, viewable_type, external_url, position)
    }.to have_enqueued_job(described_class)
      .with(viewable_id, viewable_type, external_url, position)
      .on_queue(queue_name)
  end

  context "when performing the job" do
    let(:image) { variant.images.last }
    # Real image bytes: the media reads what a file is from its bytes.
    let(:response_body) { File.binread(Spree::Core::Engine.root.join('spec/fixtures/files/icon_256x256.png')) }
    let(:response) { instance_double(Net::HTTPResponse, code: '200', body: response_body) }

    before do
      allow(SsrfFilter).to receive(:get).and_return(response)
    end

    it "downloads and attaches image from the URL" do
      expect { subject }.to change(Spree::Media, :count).by(1)
      expect(image.attachment).to be_attached
      expect(image.external_url).to eq(external_url.strip)
      expect(image.position).to eq(1)
    end

    context 'with position' do
      let(:position) { 2 }

      it "sets the position if provided" do
        subject
        expect(image.position).to eq(position)
      end
    end

    context "when image already exists with the given external_url" do
      let!(:image) { create(:media, viewable: variant) }

      before do
        image.external_url = external_url.strip
        image.save!
      end

      it "does not re-download but triggers save!" do
        expect(SsrfFilter).not_to receive(:get)
        expect { subject }.not_to change(image, :attachment)
      end
    end

    context 'when the source system names the media' do
      let(:external_id) { { 'system' => 'dam', 'external_id' => 'ASSET-9' } }

      it 'records that identity on the media' do
        subject

        expect(image.external_id_for('dam')).to eq('ASSET-9')
      end

      # A DAM may move the file and keep the id; matching on the URL would
      # then import a second copy of the same asset.
      it 'finds the media again by that identity even when the URL changed' do
        subject
        first = image

        expect(SsrfFilter).to receive(:get).once.and_return(response)
        described_class.new(viewable_id, viewable_type, 'https://cdn.example.com/moved.jpg', external_id, position).perform_now

        expect(variant.images.reload.count).to eq(1)
        expect(first.reload.external_url).to eq('https://cdn.example.com/moved.jpg')
      end

      it 'records every system that names the same asset' do
        described_class.new(viewable_id, viewable_type, external_url,
                            [{ 'system' => 'dam', 'external_id' => 'ASSET-9' },
                             { 'system' => 'pim', 'external_id' => 'SKU-2' }], position).perform_now
        media = variant.images.last

        expect(media.external_id_for('dam')).to eq('ASSET-9')
        expect(media.external_id_for('pim')).to eq('SKU-2')
      end

      it 'files a bare id under the default system' do
        described_class.new(viewable_id, viewable_type, external_url, 'ASSET-1', position).perform_now

        expect(variant.images.last.external_id_for(described_class::DEFAULT_EXTERNAL_SYSTEM)).to eq('ASSET-1')
      end
    end

    context 'when skip_import? returns true' do
      before do
        allow(image).to receive(:skip_import?).and_return(true)
        image.external_url = external_url.strip
        image.save!
      end

      let!(:image) { create(:media, viewable: variant) }

      it "does not download the image" do
        expect(SsrfFilter).not_to receive(:get)
        expect { subject }.not_to change(image, :attachment)
      end
    end

    context 'when URL resolves to private IP (SSRF)' do
      before do
        allow(SsrfFilter).to receive(:get).and_raise(SsrfFilter::PrivateIPAddress, 'URL resolves to a blocked internal address')
      end

      it 'discards the job without downloading' do
        expect { subject }.not_to change(Spree::Media, :count)
      end
    end

    context 'when the remote host cannot be reached' do
      [
        Errno::ECONNREFUSED.new('Failed to open TCP connection to 192.0.2.1:8080'),
        Errno::ECONNRESET.new,
        Net::OpenTimeout.new('execution expired'),
        Net::ReadTimeout.new,
        SocketError.new('getaddrinfo: Name or service not known'),
        OpenSSL::SSL::SSLError.new('certificate verify failed'),
        SsrfFilter::UnresolvedHostname.new("Could not resolve hostname 'cdn.example.com'")
      ].each do |error|
        it "retries the fetch on #{error.class} instead of raising" do
          allow(SsrfFilter).to receive(:get).and_raise(error)

          expect { subject }.to have_enqueued_job(described_class)
          expect(Spree::Media.count).to eq(0)
        end
      end

      it 'gives up quietly once the attempts are used up' do
        allow(SsrfFilter).to receive(:get).and_raise(Errno::ECONNREFUSED)
        allow(Rails.logger).to receive(:warn)
        job = described_class.new(viewable_id, viewable_type, external_url, external_id, position)
        # retry_on counts attempts per handler, keyed by its exception list.
        job.exception_executions = {
          [described_class::FetchFailed].to_s => Spree::Config.images_save_from_url_job_attempts.to_i - 1
        }

        expect { job.perform_now }.not_to have_enqueued_job(described_class)
        expect(Spree::Media.count).to eq(0)
        expect(Rails.logger).to have_received(:warn).with(/Gave up fetching #{Regexp.escape(external_url)}: Errno::ECONNREFUSED/)
      end
    end

    # A failure of this server, not of the remote host, is not swallowed.
    context 'when the download cannot be written to disk' do
      it 'raises instead of retrying' do
        allow(Tempfile).to receive(:new).and_raise(Errno::ENOSPC)

        expect { subject }.to raise_error(Errno::ENOSPC)
        expect(described_class).not_to have_been_enqueued
        expect(Spree::Media.count).to eq(0)
      end
    end

    context 'when the URL responds with an error status' do
      let(:response) { instance_double(Net::HTTPResponse, code: '503', body: 'Service Unavailable') }

      it 'retries the fetch without attaching the error page' do
        expect { subject }.to have_enqueued_job(described_class)
        expect(Spree::Media.count).to eq(0)
      end

      # A large error page must not trip the image size limit and be
      # discarded as an oversized image: the status is checked first.
      it 'retries a streamed error response without reading its body' do
        allow(Spree::Config).to receive(:max_image_download_size).and_return(1024)
        streamed = double('response', code: '503')
        allow(streamed).to receive(:[]).with('Content-Length').and_return('1048576')
        expect(streamed).not_to receive(:read_body)
        allow(SsrfFilter).to receive(:get) do |&block|
          block.call(streamed)
          response
        end

        expect { subject }.to have_enqueued_job(described_class)
        expect(Spree::Media.count).to eq(0)
      end
    end

    context 'when the URL redirects to the file' do
      let(:response) { instance_double(Net::HTTPResponse, code: '200', body: nil) }

      it 'discards the redirect body and attaches the final response' do
        redirect = double('redirect', code: '301')
        allow(redirect).to receive(:[]).with('Content-Length').and_return(nil)
        allow(redirect).to receive(:read_body).and_yield('Moved')
        final = double('response', code: '200')
        allow(final).to receive(:[]).with('Content-Length').and_return(nil)
        allow(final).to receive(:read_body).and_yield(response_body)
        allow(SsrfFilter).to receive(:get) do |&block|
          block.call(redirect)
          block.call(final)
          response
        end

        expect { subject }.to change(Spree::Media, :count).by(1)
        expect(image.attachment).to be_attached
      end

      it 'refuses a redirect body over the size limit instead of holding it in memory' do
        allow(Spree::Config).to receive(:max_image_download_size).and_return(10)
        redirect = double('redirect', code: '302')
        allow(redirect).to receive(:[]).with('Content-Length').and_return(nil)
        allow(redirect).to receive(:read_body).and_yield('x' * 8).and_yield('x' * 8)
        allow(SsrfFilter).to receive(:get) { |&block| block.call(redirect) }

        expect { subject }.to raise_error(StandardError, /exceeds the maximum allowed size/)
        expect(Spree::Media.count).to eq(0)
      end
    end

    context 'when the URL serves bytes that are not an image' do
      let(:response_body) { 'not an image' }

      it 'retries without writing the media or its external URL' do
        expect { subject }.to have_enqueued_job(described_class)
        expect(Spree::Media.count).to eq(0)
        expect(Spree::CustomField.count).to eq(0)
      end
    end

    context 'when the external URL cannot be saved' do
      before do
        allow_any_instance_of(Spree::Media).to receive(:external_url=).
          and_raise(ActiveRecord::RecordInvalid.new(Spree::Media.new))
      end

      it 'rolls the media back so the retry does not duplicate it' do
        expect { subject }.to have_enqueued_job(described_class)
        expect(Spree::Media.count).to eq(0)
      end
    end

    context 'when downloaded file exceeds max size' do
      let(:max_size) { 1024 }
      let(:response_body) { 'x' * (max_size + 1) }

      before do
        allow(Spree::Config).to receive(:max_image_download_size).and_return(max_size)
      end

      it 'raises an error about file size' do
        expect { subject }.to raise_error(StandardError, /exceeds the maximum allowed size/)
      end

      # The limit applies to what is downloaded, not only to what is attached:
      # an endless response is cut off once it passes the limit.
      it 'stops reading a streamed body once it passes the limit' do
        chunks_read = 0
        streamed = double('response', code: '200')
        allow(streamed).to receive(:[]).with('Content-Length').and_return(nil)
        allow(streamed).to receive(:read_body) do |&block|
          loop do
            chunks_read += 1
            block.call('x' * 512)
          end
        end
        allow(SsrfFilter).to receive(:get) { |&block| block.call(streamed); response }

        expect { subject }.to raise_error(StandardError, /exceeds the maximum allowed size/)
        expect(chunks_read).to eq(3)
      end

      it 'refuses a declared length over the limit before reading' do
        streamed = double('response', code: '200')
        allow(streamed).to receive(:[]).with('Content-Length').and_return((max_size + 1).to_s)
        expect(streamed).not_to receive(:read_body)
        allow(SsrfFilter).to receive(:get) { |&block| block.call(streamed); response }

        expect { subject }.to raise_error(StandardError, /exceeds the maximum allowed size/)
      end
    end

    context 'when link_variant_id is provided for a product-level upload' do
      let(:product) { create(:product) }
      let!(:linked_variant) { create(:variant, product: product) }
      let(:viewable_id) { product.id }
      let(:viewable_type) { 'Spree::Product' }

      subject { described_class.new(viewable_id, viewable_type, external_url, external_id, position, linked_variant.id).perform_now }

      it 'creates a VariantMedia row linking the asset to the variant' do
        expect { subject }.to change(Spree::VariantMedia, :count).by(1)

        link = Spree::VariantMedia.last
        expect(link.variant_id).to eq(linked_variant.id)
        expect(link.media_id).to eq(Spree::Media.last.id)
      end

      it 'is idempotent on repeat invocations' do
        described_class.new(viewable_id, viewable_type, external_url, external_id, position, linked_variant.id).perform_now
        expect {
          described_class.new(viewable_id, viewable_type, external_url, external_id, position, linked_variant.id).perform_now
        }.not_to change(Spree::VariantMedia, :count)
      end
    end

    context 'when link_variant_id is provided but the upload targets a Variant (legacy)' do
      let!(:linked_variant) { create(:variant) }

      subject { described_class.new(variant.id, 'Spree::Variant', external_url, external_id, position, linked_variant.id).perform_now }

      it 'does not create a VariantMedia row (variant-pinned uploads bypass the join)' do
        expect { subject }.not_to change(Spree::VariantMedia, :count)
      end
    end
  end
end
