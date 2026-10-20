require 'spec_helper'

describe Spree::Emails::Branding do
  it 'keeps the shipped design when nothing is set' do
    expect(described_class.new.to_h).to include(
      'background_color' => '#FFFFFF', 'card_color' => '#F6F6F6', 'accent_color' => nil,
      'button_color' => '#FFFFFF', 'button_border' => '1px solid #E8E9E9', 'font' => 'inter',
      'heading_font_family' => 'Geist, Inter, Helvetica, Arial, sans-serif', 'font_url' => nil
    )
  end

  it 'gives buttons the accent with whichever of black or white reads on it' do
    expect(described_class.new(accent_color: '#ffee00').to_h).to include('button_color' => '#FFEE00', 'button_text_color' => '#000000', 'link_color' => '#FFEE00')
    expect(described_class.new(accent_color: '#1a237e').to_h).to include('button_text_color' => '#FFFFFF')
  end

  it 'loads a web font with its fallback stack' do
    expect(described_class.new(font: 'roboto').to_h).to include('font_family' => 'Roboto, Helvetica, Arial, sans-serif', 'font_url' => a_string_including('Roboto'))
  end

  it 'never lets anything but a color or a known font through to the CSS' do
    branding = described_class.new(accent_color: 'red;}</style><script>', text_color: 'blue', font: 'comic')

    expect(branding).not_to be_valid
    expect(branding.to_h).to include('accent_color' => nil, 'text_color' => '#726A6A', 'font' => 'inter')
  end

  describe 'on a store' do
    let(:store) { build(:store) }

    it 'refuses a branding setting that is not a color or a known font' do
      store.preferred_email_card_color = '#12345'
      store.preferred_email_font = 'comic'

      expect(store).not_to be_valid
      expect(store.errors[:preferred_email_card_color]).to be_present
      expect(store.errors[:preferred_email_font]).to be_present
    end

    it 'previews unsaved values over the saved ones' do
      store.preferred_email_text_color = '#111111'

      expect(store.email_branding(card_color: '#222222').to_h).to include('text_color' => '#111111', 'card_color' => '#222222')
    end
  end
end
