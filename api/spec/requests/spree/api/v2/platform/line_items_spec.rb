require 'spec_helper'

describe 'API V2 Platform Line Items Spec' do
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  let!(:line_items) { create_list(:line_item, 5) }
  
  describe 'line_items#index' do
    context 'with no params' do
      before { get '/api/v2/platform/line_items', headers: bearer_token }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all line_items' do
        expect(json_response['data'].count).to eq store.line_items.count
        expect(json_response['data'].first).to have_type('line_item')
      end
    end

    context 'current store' do
      let(:store_2) { create(:store) }
      let(:order_2) { create(:order, store: store_2) }
      let!(:line_item_from_another_store) { create(:line_item, order: order_2) }

      before { get '/api/v2/platform/line_items', headers: bearer_token }

      it 'returns line items from this store only' do
        expect(json_response['data'].count).to eq store.line_items.count
        line_item_ids = json_response['data'].pluck(:id)

        expect(line_item_ids).not_to include(line_item_from_another_store.id)
        expect(line_item_ids).to match_array(store.line_items.ids.map(&:to_s))
      end
    end

    context 'filtering' do
      context 'by order_id' do
        let(:order) { create(:order, store: store) }
        let!(:line_item) { create(:line_item, order: order) }

        before { get "/api/v2/platform/line_items?filter[order_id_eq]=#{order.id}", headers: bearer_token }

        it 'returns line items from this order' do
          expect(json_response['data'].count).to eq 1
          expect(json_response['data'].first['id']).to eq line_item.id.to_s
        end
      end

      context 'by price' do
        let(:order) { create(:order, store: store) }
        let!(:line_item) { create(:line_item, order: order, price: 100) }

        before { get "/api/v2/platform/line_items?filter[price_gteq]=100", headers: bearer_token }

        it 'returns line items with price greater than or equal to the given price' do
          expect(json_response['data'].count).to eq 1
          expect(json_response['data'].first['id']).to eq line_item.id.to_s
        end
      end
    end

    context 'sorting' do
      context 'by price' do
        before { store.line_items.each_with_index { |p, i| p.update(price: p.price + i) } }

        context 'ascending order' do
          before { get '/api/v2/platform/line_items?sort=price', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns line items sorted by price' do
            expect(json_response['data'].count).to      eq store.line_items.count
            expect(json_response['data'].pluck(:id)).to eq store.line_items.order(price: :asc).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/line_items?sort=-price', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns line items sorted by price with descending order' do
            expect(json_response['data'].count).to      eq store.line_items.count
            expect(json_response['data'].pluck(:id)).to eq store.line_items.order(price: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'by updated_at' do
        context 'ascending order' do
          before { get '/api/v2/platform/line_items?sort=updated_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns line items sorted by updated_at' do
            expect(json_response['data'].count).to      eq store.line_items.count
            expect(json_response['data'].pluck(:id)).to eq store.line_items.order(:updated_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/line_items?sort=-updated_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns line items sorted by updated_at with descending order' do
            expect(json_response['data'].count).to      eq store.line_items.count
            expect(json_response['data'].pluck(:id)).to eq store.line_items.order(updated_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'by created_at' do
        context 'ascending order' do
          before { get '/api/v2/platform/line_items?sort=created_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns line items sorted by created_at' do
            expect(json_response['data'].count).to      eq store.line_items.count
            expect(json_response['data'].pluck(:id)).to eq store.line_items.order(:created_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/line_items?sort=-created_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns line items sorted by created_at with descending order' do
            expect(json_response['data'].count).to      eq store.line_items.count
            expect(json_response['data'].pluck(:id)).to eq store.line_items.order(created_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end
    end

    context 'paginate line items' do
      context 'with specified pagination params' do
        context 'when per_page is between 1 and default value' do
          before { get '/api/v2/platform/line_items?page=1&per_page=2', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns the default number of line items' do
            expect(json_response['data'].count).to eq 2
          end

          it 'returns proper meta data' do
            expect(json_response['meta']['count']).to       eq 2
            expect(json_response['meta']['total_count']).to eq store.line_items.count
          end

          it 'returns proper links data' do
            expect(json_response['links']['self']).to include('/api/v2/platform/line_items?page=1&per_page=2')
            expect(json_response['links']['next']).to include('/api/v2/platform/line_items?page=2&per_page=2')
            expect(json_response['links']['prev']).to include('/api/v2/platform/line_items?page=1&per_page=2')
          end
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/platform/line_items', headers: bearer_token }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount line items' do
          expect(json_response['data'].count).to eq store.line_items.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq store.line_items.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/platform/line_items')
          expect(json_response['links']['next']).to include('/api/v2/platform/line_items?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/platform/line_items?page=1')
        end
      end
    end
  end
end
