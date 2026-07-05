require 'spec_helper'

RSpec.describe Spree::Admin::ActionText::VideoEmbedsController do
  stub_authorization!

  describe '#create' do
    subject { post :create, params: { url: url } }

    let(:url) { 'https://www.youtube.com/watch?v=2iGBuLQ3S0c' }
    let(:video_embed) { ActionText::VideoEmbed.last }

    context 'when the URL is valid' do
      let(:oembed_response) do
        instance_double(
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

      before do
        allow(OEmbed::Providers).to receive(:get).with(url).and_return(oembed_response)
      end

      it 'creates the video embed attachment' do
        expect { subject }.to change(ActionText::VideoEmbed, :count).by(1)

        expect(response).to have_http_status(:created)

        expect(video_embed).to be_present
        expect(video_embed.url).to eq(url)
        expect(video_embed.thumbnail_url).to include('2iGBuLQ3S0c')

        expect(video_embed.raw_html).to start_with('<iframe')
        expect(video_embed.raw_html).to include('src="https://www.youtube.com/embed/2iGBuLQ3S0c?feature=oembed"')

        expect(JSON.parse(response.body)['sgid']).to eq(video_embed.attachable_sgid)
      end
    end

    context 'when the URL is invalid' do
      before do
        allow(OEmbed::Providers).to receive(:get).with(url).and_raise(OEmbed::Error)
      end

      it 'responds with a not found message' do
        expect { subject }.not_to change(ActionText::VideoEmbed, :count)

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq(I18n.t('action_text.video_embed.not_found'))
      end
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: video_embed.attachable_sgid } }

    let!(:video_embed) do
      ActionText::VideoEmbed.create!(
        url: 'https://www.youtube.com/watch?v=2iGBuLQ3S0c',
        raw_html: "<iframe width=\"200\" height=\"113\" src=\"https://www.youtube.com/embed/2iGBuLQ3S0c?feature=oembed\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share\" referrerpolicy=\"strict-origin-when-cross-origin\" allowfullscreen title=\"RailsConf 2020 CE - Advanced ActionText: Attaching any Model in rich text by Chris Oliver\"></iframe>",
        thumbnail_url: 'https://i.ytimg.com/vi/2iGBuLQ3S0c/hqdefault.jpg'
      )
    end

    it 'removes the video embed attachment' do
      expect { subject }.to change(ActionText::VideoEmbed, :count).from(1).to(0)
      expect { video_embed.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
