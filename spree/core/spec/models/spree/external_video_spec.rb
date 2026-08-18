require 'spec_helper'

RSpec.describe Spree::ExternalVideo do
  describe '.parse' do
    context 'YouTube' do
      {
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ' => 'dQw4w9WgXcQ',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=42' => 'dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ' => 'dQw4w9WgXcQ',
        'https://www.youtube.com/embed/dQw4w9WgXcQ' => 'dQw4w9WgXcQ',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ' => 'dQw4w9WgXcQ'
      }.each do |url, video_id|
        it "reads #{url}" do
          video = described_class.parse(url)

          expect(video.provider).to eq('youtube')
          expect(video.video_id).to eq(video_id)
          expect(video.embed_url).to eq("https://www.youtube.com/embed/#{video_id}")
          expect(video.watch_url).to eq("https://www.youtube.com/watch?v=#{video_id}")
          expect(video.thumbnail_url).to eq("https://img.youtube.com/vi/#{video_id}/hqdefault.jpg")
        end
      end
    end

    context 'Vimeo' do
      {
        'https://vimeo.com/123456789' => '123456789',
        'https://player.vimeo.com/video/123456789' => '123456789',
        'https://vimeo.com/channels/staffpicks/123456789' => '123456789'
      }.each do |url, video_id|
        it "reads #{url}" do
          video = described_class.parse(url)

          expect(video.provider).to eq('vimeo')
          expect(video.video_id).to eq(video_id)
          expect(video.embed_url).to eq("https://player.vimeo.com/video/#{video_id}")
          expect(video.watch_url).to eq("https://vimeo.com/#{video_id}")
        end
      end

      it 'has no provider thumbnail' do
        expect(described_class.parse('https://vimeo.com/123456789').thumbnail_url).to be_nil
      end
    end

    # The dashboard mirrors this parser to validate as the merchant types. If
    # the two disagree, the dialog accepts a link the server then rejects —
    # failing the whole product save.
    it 'accepts a trailing slash, as an address-bar copy carries' do
      expect(described_class.parse('https://youtu.be/dQw4w9WgXcQ/')&.video_id).to eq('dQw4w9WgXcQ')
      expect(described_class.parse('https://vimeo.com/123456789/')&.video_id).to eq('123456789')
      expect(described_class.parse('https://www.youtube.com/watch/?v=dQw4w9WgXcQ')&.video_id).
        to eq('dQw4w9WgXcQ')
    end

    it 'ignores surrounding whitespace' do
      expect(described_class.parse('  https://vimeo.com/123456789  ').video_id).to eq('123456789')
    end

    [
      'https://example.com/video.mp4',
      'https://www.youtube.com/watch?v=short',
      'https://vimeo.com/not-a-number',
      'javascript:alert(1)',
      'not a url',
      '',
      nil
    ].each do |url|
      it "returns nil for #{url.inspect}" do
        expect(described_class.parse(url)).to be_nil
      end
    end
  end

  describe '.supported?' do
    it 'is true for a link Spree can embed' do
      expect(described_class).to be_supported('https://vimeo.com/123456789')
    end

    it 'is false for anything else' do
      expect(described_class).not_to be_supported('https://example.com/clip.mp4')
    end
  end
end
