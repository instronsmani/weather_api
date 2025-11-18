require 'rails_helper'

RSpec.describe Api::WeatherController, type: :controller do
  describe 'GET #show' do
    shared_examples 'responds with bad_gateway' do
      it 'responds with 502 Bad Gateway' do
        expect(response).to have_http_status(:bad_gateway)
      end
    end

    shared_examples 'responds with ok' do
      it 'responds with 200 OK' do
        expect(response).to have_http_status(:ok)
      end
    end

    shared_examples 'renders json body' do |expected|
      it "renders JSON body #{expected.inspect}" do
        expect(JSON.parse(response.body)).to eq(expected)
      end
    end

    context 'negative cases' do
      context 'when service returns an error' do
        before do
          svc = double(fetch: { error: 'weather_api_error' })
          allow(WeatherService).to receive(:new).and_return(svc)
          get :show, params: { location: 'nowhere' }
        end

        include_examples 'responds with bad_gateway'
        include_examples 'renders json body', ({ 'error' => 'weather_api_error' })
      end

      context 'when location is missing (edge negative case)' do
        before do
          svc = double(fetch: { error: 'invalid_location' })
          allow(WeatherService).to receive(:new).and_return(svc)
          get :show, params: {}
        end

        include_examples 'responds with bad_gateway'
        include_examples 'renders json body', ({ 'error' => 'invalid_location' })
      end
    end

    context 'positive cases' do
      context 'when service returns data (uncached)' do
        before do
          payload = { 'tempMax' => 10, 'tempMin' => 2, 'tempCurrent' => 6 }
          svc = double(fetch: { data: payload, cached: false })
          allow(WeatherService).to receive(:new).and_return(svc)
          get :show, params: { location: 'London' }
        end

        include_examples 'responds with ok'

        it 'renders data in response body' do
          expect(JSON.parse(response.body)['data']).to eq({ 'tempMax' => 10, 'tempMin' => 2, 'tempCurrent' => 6 })
        end

        it 'renders cached flag as false' do
          expect(JSON.parse(response.body)['cached']).to eq(false)
        end
      end

      context 'when service returns cached data' do
        before do
          payload = { 'tempMax' => 21, 'tempMin' => 11, 'tempCurrent' => 16 }
          svc = double(fetch: { data: payload, cached: true })
          allow(WeatherService).to receive(:new).and_return(svc)
          get :show, params: { id: 'Bangalore' }
        end

        include_examples 'responds with ok'

        it 'renders data in response body' do
          expect(JSON.parse(response.body)['data']).to eq({ 'tempMax' => 21, 'tempMin' => 11, 'tempCurrent' => 16 })
        end

        it 'renders cached flag as true' do
          expect(JSON.parse(response.body)['cached']).to eq(true)
        end
      end
    end
  end
end
