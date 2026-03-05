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
    let(:image_scope) { double('image_scope') }
    let(:image) { variant.images.last }
    let(:file_double) { StringIO.new("imagecontent") }
    let(:filename) { "bar_image.png" }
    let(:uri_double) {
      instance_double(URI::HTTPS, path: "/foo/bar_image.png", open: file_double)
    }

    before do
      allow(URI).to receive(:parse).with(external_url.strip).and_return(uri_double)
      allow(uri_double).to receive(:scheme).and_return('https')
      allow(Spree::UrlSafety).to receive(:validate_url!).and_return(nil)
    end

    it "downloads and attaches image from the URL" do
      expect { subject }.to change(Spree::Image, :count).by(1)
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
      let!(:image) { create(:image, viewable: variant) }

      before do
        image.external_url = external_url.strip
        image.save!
      end

      it "does not re-download but triggers save!" do
        expect(URI).not_to receive(:parse)
        expect(URI).not_to receive(:open)
        expect { subject }.not_to change(image, :attachment)
      end
    end

    context 'when skip_import? returns true' do
      before do
        allow(image).to receive(:skip_import?).and_return(true)
        image.external_url = external_url.strip
        image.save!
      end

      let!(:image) { create(:image, viewable: variant) }

      it "does not download the image" do
        expect(URI).not_to receive(:parse)
        expect(URI).not_to receive(:open)
        expect { subject }.not_to change(image, :attachment)
      end
    end

    context 'when URL resolves to private IP (SSRF)' do
      before do
        allow(Spree::UrlSafety).to receive(:validate_url!).and_raise(Spree::UrlSafety::SsrfError, 'URL resolves to a blocked internal address')
      end

      it 'discards the job without downloading' do
        expect { subject }.not_to change(Spree::Image, :count)
      end
    end

    context 'when downloaded file exceeds max size' do
      let(:max_size) { 1024 }
      let(:oversized_content) { 'x' * (max_size + 1) }
      let(:oversized_io) { StringIO.new(oversized_content) }
      let(:uri_double) {
        instance_double(URI::HTTPS, path: "/foo/bar_image.png", open: oversized_io)
      }

      before do
        allow(Spree::Config).to receive(:max_image_download_size).and_return(max_size)
        allow(oversized_io).to receive(:meta).and_return({})
      end

      it 'raises an error about file size' do
        expect { subject }.to raise_error(StandardError, /exceeds the maximum allowed size/)
      end
    end

    context 'when Content-Length header exceeds max size' do
      let(:max_size) { 1024 }
      let(:uri_double) {
        instance_double(URI::HTTPS, path: "/foo/bar_image.png", open: file_double)
      }

      before do
        allow(Spree::Config).to receive(:max_image_download_size).and_return(max_size)
        allow(file_double).to receive(:meta).and_return({ 'content-length' => '2048' })
      end

      it 'raises an error about file size' do
        expect { subject }.to raise_error(StandardError, /exceeds the maximum allowed size/)
      end
    end
  end
end
