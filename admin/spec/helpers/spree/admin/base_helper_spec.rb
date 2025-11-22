require 'spec_helper'

describe Spree::Admin::BaseHelper do
  describe '#render_avatar' do
    let(:user) { create(:admin_user) }

    context 'when user has an avatar' do
      before { user.avatar.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures/thinking-cat.jpg'), filename: 'thinking-cat.jpg') }

      it 'returns the avatar url' do
        ActiveStorage::Current.url_options = { host: 'localhost', port: 3000 }
        expect(render_avatar(user)).to match(/rails\/active_storage/)
        expect(render_avatar(user)).to match(/thinking-cat\.jpg/)
      end
    end

    context 'when user does not have an avatar' do
      it 'returns initials' do
        expect(render_avatar(user)).to match(/avatar/)
      end
    end
  end

  describe '#spree_time_ago' do
    it 'returns the local time ago with a tooltip' do
      time = Time.zone.parse('2025-10-21 12:00')
      html = helper.spree_time_ago(time)
      expect(html).to include('<time datetime="2025-10-21T12:00')
      expect(html).to include('tooltip-container')
    end

    it 'returns empty string for blank time' do
      expect(helper.spree_time_ago(nil)).to eq('')
    end
  end

  describe '#render_admin_partials' do
    before do
      # Set up test partials
      allow(Rails.application.config.spree_admin).to receive(:product_form_partials).and_return(['spree/admin/products/test_partial'])
    end

    context 'with new naming convention (without _partials suffix)' do
      it 'renders partials for the given section' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', {}).and_return('partial content')

        result = helper.render_admin_partials(:product_form)

        expect(result).to eq('partial content')
      end

      it 'passes options to the partials' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', { product: 'test' }).and_return('partial with options')

        result = helper.render_admin_partials(:product_form, { product: 'test' })

        expect(result).to eq('partial with options')
      end

      it 'renders multiple partials' do
        allow(Rails.application.config.spree_admin).to receive(:product_form_partials).and_return([
          'spree/admin/products/partial1',
          'spree/admin/products/partial2'
        ])
        allow(helper).to receive(:render).with('spree/admin/products/partial1', {}).and_return('content1')
        allow(helper).to receive(:render).with('spree/admin/products/partial2', {}).and_return('content2')

        result = helper.render_admin_partials(:product_form)

        expect(result).to eq('content1content2')
      end
    end

    context 'with old naming convention (with _partials suffix)' do
      it 'renders partials for the given section (backward compatibility)' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', {}).and_return('partial content')

        result = helper.render_admin_partials(:product_form_partials)

        expect(result).to eq('partial content')
      end

      it 'passes options to the partials' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', { product: 'test' }).and_return('partial with options')

        result = helper.render_admin_partials(:product_form_partials, { product: 'test' })

        expect(result).to eq('partial with options')
      end
    end

    context 'with empty partials array' do
      it 'returns empty string' do
        allow(Rails.application.config.spree_admin).to receive(:dashboard_analytics_partials).and_return([])

        result = helper.render_admin_partials(:dashboard_analytics)

        expect(result).to eq('')
      end
    end
  end
end
