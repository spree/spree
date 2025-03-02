require 'spec_helper'

RSpec.describe Spree::PageSections::Video do
  let(:valid_oembed_response) do
    double(
      OEmbed::Response::Video,
      fields: {
          'title' => 'RailsConf 2020 CE - Advanced ActionText: Attaching any Model in rich text by Chris Oliver',
          'author_name' => 'Confreaks',
          'author_url' => 'https://www.youtube.com/@Confreaks',
          'type' => 'video',
          'height' => 113,
          'width' => 200,
          'version' => '1.0',
          'provider_name' => 'YouTube',
          'provider_url' => 'https://www.youtube.com/',
          'thumbnail_height' => 360,
          'thumbnail_width' => 480,
          'thumbnail_url' => 'https://i.ytimg.com/vi/2iGBuLQ3S0c/hqdefault.jpg',
          'html' => "<iframe width=\"200\" height=\"113\" src=\"https://www.youtube.com/embed/2iGBuLQ3S0c?feature=oembed\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share\" referrerpolicy=\"strict-origin-when-cross-origin\" allowfullscreen title=\"RailsConf 2020 CE - Advanced ActionText: Attaching any Model in rich text by Chris Oliver\"></iframe>"
      }
    )
  end

  describe 'after_create :create_video_embed' do
    subject { create(:video_page_section, preferred_youtube_video_url: url) }

    let(:url) { 'https://www.youtube.com/watch?v=2iGBuLQ3S0c' }
    let(:video_embed) { subject.video_embed }

    context 'when the URL is valid' do
      before do
        allow(OEmbed::Providers).to receive(:get).with(url).and_return(valid_oembed_response)
      end

      it 'creates the video embed attachment' do
        expect { subject }.to change(ActionText::VideoEmbed, :count).by(1)

        expect(subject.preferred_youtube_video_url).to eq(url)
        expect(subject.preferred_youtube_video_embed_id.to_s).to eq(video_embed.id.to_s)

        expect(video_embed).to be_present
        expect(video_embed.url).to eq(url)
        expect(video_embed.thumbnail_url).to include('2iGBuLQ3S0c')

        expect(video_embed.raw_html).to start_with('<iframe')
        expect(video_embed.raw_html).to include('src="https://www.youtube.com/embed/2iGBuLQ3S0c?feature=oembed"')
      end
    end

    context 'when the URL is invalid' do
      before do
        allow(OEmbed::Providers).to receive(:get).with(url).and_raise(OEmbed::Error)
      end

      it 'creates no video embed attachment' do
        expect { subject }.not_to change(ActionText::VideoEmbed, :count)

        expect(subject.preferred_youtube_video_url).to eq(url)
        expect(subject.preferred_youtube_video_embed_id).to be_nil

        expect(video_embed).to be_nil
      end
    end
  end

  describe 'after_update :update_video_embed' do
    subject { video_page_section.update(preferred_youtube_video_url: url_2) }

    let(:video_page_section) { create(:video_page_section, preferred_youtube_video_url: url_1) }

    let(:url_1) { 'https://www.youtube.com/watch?v=2iGBuLQ3S0c' }
    let(:url_2) { 'https://www.youtube.com/watch?v=2iGBuLQ3S0d' }

    let(:video_embed) { video_page_section.reload.video_embed }

    let(:valid_oembed_response_2) do
      double(
        OEmbed::Response::Video,
        fields: {
            'title' => 'RailsConf 2020 CE - Advanced ActionText: Attaching any Model in rich text by Chris Oliver',
            'author_name' => 'Confreaks',
            'author_url' => 'https://www.youtube.com/@Confreaks',
            'type' => 'video',
            'height' => 113,
            'width' => 200,
            'version' => '1.0',
            'provider_name' => 'YouTube',
            'provider_url' => 'https://www.youtube.com/',
            'thumbnail_height' => 360,
            'thumbnail_width' => 480,
            'thumbnail_url' => 'https://i.ytimg.com/vi/2iGBuLQ3S0d/hqdefault.jpg',
            'html' => "<iframe width=\"200\" height=\"113\" src=\"https://www.youtube.com/embed/2iGBuLQ3S0d?feature=oembed\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share\" referrerpolicy=\"strict-origin-when-cross-origin\" allowfullscreen title=\"RailsConf 2020 CE - Advanced ActionText: Attaching any Model in rich text by Chris Oliver\"></iframe>"
        }
      )
    end

    context 'when the URL is valid' do
      before do
        allow(OEmbed::Providers).to receive(:get).with(url_1).and_return(valid_oembed_response)
        allow(OEmbed::Providers).to receive(:get).with(url_2).and_return(valid_oembed_response_2)

        video_page_section
      end

      it 'updates the video embed attachment' do
        subject

        expect(video_page_section.reload.preferred_youtube_video_url).to eq(url_2)
        expect(video_page_section.preferred_youtube_video_embed_id.to_s).to eq(video_embed.id.to_s)

        expect(video_embed).to be_present
        expect(video_embed.url).to eq(url_2)
        expect(video_embed.thumbnail_url).to include('2iGBuLQ3S0d')

        expect(video_embed.raw_html).to start_with('<iframe')
        expect(video_embed.raw_html).to include('src="https://www.youtube.com/embed/2iGBuLQ3S0d?feature=oembed"')
      end
    end

    context 'when the URL is invalid' do
      before do
        allow(OEmbed::Providers).to receive(:get).with(url_1).and_return(valid_oembed_response)
        allow(OEmbed::Providers).to receive(:get).with(url_2).and_raise(OEmbed::Error)

        video_page_section
      end

      it 'updates the page section with no video embed attachment' do
        expect { subject }.to change(ActionText::VideoEmbed, :count).by(-1)
        expect(video_embed).to be_nil
      end
    end
  end
end
