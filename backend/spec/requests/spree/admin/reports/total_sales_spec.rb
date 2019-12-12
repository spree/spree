require 'spec_helper'

describe 'Admin Reports - total sales spec', type: :request do
  stub_authorization!

  let!(:order1) { create(:completed_order_with_totals) }
  let!(:order2) { create(:completed_order_with_totals) }
  let!(:order3) { create(:completed_order_with_totals) }

  before do
    order1.update(completed_at: '2019-10-11', total: 100)
    order2.update(completed_at: '2019-10-14', total: 200)
    order3.update(completed_at: '2019-10-15', total: 350)
  end

  let(:params) do
    { completed_at_min: '2019-10-11', completed_at_max: '2019-10-17' }
  end

  describe 'total_sales#show' do
    context 'with valid date range' do
      before { get '/admin/reports/total_sales.json', params: params }

      let(:json_response) { JSON.parse(response.body) }

      it 'returns 200 HTTP status' do
        expect(response).to have_http_status(:ok)
      end

      it 'return JSON data for charts' do
        expect(json_response['labels']).to eq ['2019-10-11', '2019-10-12', '2019-10-13', '2019-10-14', '2019-10-15', '2019-10-16', '2019-10-17']
        expect(json_response['data']).to   eq ['100.0', '0.0', '0.0', '200.0', '350.0', '0.0', '0.0']
      end
    end

    context 'generate csv report' do
      context 'without date range' do
        let! :csv_response do
          <<-CSV.strip_heredoc
            date,total_sales
            2019-12-04,0.0
            2019-12-05,0.0
            2019-12-06,0.0
            2019-12-07,0.0
            2019-12-08,0.0
            2019-12-09,0.0
            2019-12-10,0.0
            2019-12-11,0.0
          CSV
        end

        it 'returns 200 HTTP status' do
          Timecop.freeze(2019, 12, 11) do
            get '/admin/reports/total_sales.csv'
          end

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq csv_response
          expect(response.headers['Content-Disposition']).to eq "attachment; filename=\"total_sales.csv\"; filename*=UTF-8''total_sales.csv"
          expect(response.headers['Content-Type']).to eq 'text/csv'
        end
      end
    end
  end
end
