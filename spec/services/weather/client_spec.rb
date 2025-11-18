require 'rails_helper'

RSpec.describe Weather::Client, type: :service do
  describe '#fetch' do
    let(:http_client) { double('HTTPClient') }
    let(:logger) { Rails.logger }
    subject(:client) { described_class.new(http_client: http_client, logger: logger) }

    shared_examples 'returns nil for fetch' do
      it 'returns nil' do
        expect(client.fetch(location)).to be_nil
      end
    end

    context 'when location is blank (negative case)' do
      let(:location) { ' ' }

      before do
        allow(http_client).to receive(:get)
      end

      include_examples 'returns nil for fetch'
    end

    context 'when HTTP client returns an object without code' do
      let(:location) { 'Berlin' }

      before do
        allow(http_client).to receive(:get).and_return(Object.new)
      end

      include_examples 'returns nil for fetch'
    end

    context 'when HTTP client returns non-200 status' do
      let(:location) { 'Tokyo' }

      before do
        resp = double('resp', code: 500, body: '', respond_to?: true)
        allow(http_client).to receive(:get).and_return(resp)
      end

      include_examples 'returns nil for fetch'
    end

    context 'when HTTP client returns malformed JSON' do
      let(:location) { 'Sydney' }

      before do
        resp = double('resp', code: 200, body: 'not_json')
        allow(http_client).to receive(:get).and_return(resp)
      end

      include_examples 'returns nil for fetch'
    end

    context 'when API responds with valid JSON' do
      let(:location) { 'New York' }

      before do
        ENV['WEATHER_VISUAL_CROSSING_API_KEY'] = 'fake-key'
        ENV['WEATHER_VISUAL_CROSSING_URL'] = 'https://weather.example.com'

        body = { 'days' => [ { 'tempmax' => 20.6, 'tempmin' => 10.2 } ], 'currentConditions' => { 'temp' => 15.4 } }.to_json
        resp = double('resp', code: 200, body: body)
        allow(http_client).to receive(:get).and_return(resp)
        @result = client.fetch(location)
      end

      it 'returns a Hash' do
        expect(@result).to be_a(Hash)
      end

      it 'includes tempMax with expected value' do
        expect(@result['days'].first['tempmax']).to eq(20.6)
      end

      it 'includes currentConditions with expected temp' do
        expect(@result['currentConditions']['temp']).to eq(15.4)
      end
    end
  end
end
