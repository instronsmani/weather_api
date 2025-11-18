require 'rails_helper'

RSpec.describe Weather::Formatter, type: :service do
  describe '.format' do
    shared_examples 'returns nil for payload' do
      it 'returns nil' do
        expect(described_class.format(payload)).to be_nil
      end
    end
    context 'when payload is nil' do
      let(:payload) { nil }

      include_examples 'returns nil for payload'
    end

    context 'when payload is an empty hash' do
      let(:payload) { {} }

      include_examples 'returns nil for payload'
    end

    context 'when payload has no days key' do
      let(:payload) { { 'currentConditions' => { 'temp' => 12.3 } } }

      include_examples 'returns nil for payload'
    end

    context 'when payload has no currentConditions' do
      let(:payload) { { 'days' => [ { 'tempmax' => 5, 'tempmin' => 1 } ] } }

      include_examples 'returns nil for payload'
    end

    context 'when currentConditions temp is nil' do
      let(:payload) { { 'days' => [ { 'tempmax' => 5, 'tempmin' => 1 } ], 'currentConditions' => { 'temp' => nil } } }

      include_examples 'returns nil for payload'
    end

    context 'when payload is valid (positive cases)' do
      let(:payload) do
        {
          'days' => [ { 'tempmax' => 20.6, 'tempmin' => 10.2 } ],
          'currentConditions' => { 'temp' => 15.4 }
        }
      end

      before do
        @result = described_class.format(payload)
      end

      it 'returns a Hash' do
        expect(@result).to be_a(Hash)
      end

      it "includes the 'tempMax' key with the correct value" do
        expect(@result['tempMax']).to eq(20.6)
      end

      it "includes the 'tempMin' key with the correct value" do
        expect(@result['tempMin']).to eq(10.2)
      end

      it "includes the 'tempCurrent' key with the correct value" do
        expect(@result['tempCurrent']).to eq(15.4)
      end
    end
  end
end
