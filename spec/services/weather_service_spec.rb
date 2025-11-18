require 'rails_helper'

RSpec.describe WeatherService, type: :service do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:logger) { Rails.logger }

  shared_examples 'returns error' do |expected_error|
    it "returns error #{expected_error}" do
      expect(subject.fetch).to eq({ error: expected_error })
    end
  end

  context 'when location is blank (negative case)' do
    subject { described_class.new(location: '  ', client: double('client'), cache: cache, logger: logger) }

    include_examples 'returns error', 'invalid_location'
  end

  context 'when payload is blank from client (edge case)' do
    let(:client) { double('client', fetch: nil) }
    subject { described_class.new(location: 'Paris', client: client, cache: cache, logger: logger) }

    include_examples 'returns error', 'weather_api_error'
  end

  context 'when formatter returns nil (edge case)' do
    let(:payload) do
      { 'days' => [ { 'tempmax' => 1, 'tempmin' => 0 } ], 'currentConditions' => { 'temp' => 2 } }
    end
    let(:client) { double('client', fetch: payload) }
    let(:formatter) { double('formatter', format: nil) }
    subject { described_class.new(location: 'Berlin', client: client, formatter: formatter, cache: cache, logger: logger) }

    include_examples 'returns error', 'format_error'
  end

  context 'when client raises exception (edge case)' do
    let(:client) { double('client') }
    before do
      allow(client).to receive(:fetch).and_raise(StandardError, 'boom')
    end

    subject { described_class.new(location: 'X', client: client, cache: cache, logger: logger) }

    include_examples 'returns error', 'internal_error'
  end

  context 'when upstream returns valid payload (positive cases)' do
    let(:payload) do
      {
        'days' => [ { 'tempmax' => 12.3, 'tempmin' => 5.1 } ],
        'currentConditions' => { 'temp' => 9.2 }
      }
    end
    let(:client) { double('client', fetch: payload) }
    subject { described_class.new(location: 'London', client: client, cache: cache, logger: logger) }

    before do
      cache.clear
      @result = subject.fetch
    end

    it 'returns data key' do
      expect(@result).to have_key(:data)
    end

    it 'reports cached as false on first fetch' do
      expect(@result[:cached]).to eq(false)
    end

    it 'serves subsequent call from cache' do
      second = subject.fetch
      expect(second[:cached]).to eq(true)
    end
  end
end
