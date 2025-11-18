# frozen_string_literal: true

module Weather
  class Client
    DEFAULT_PARAMS = { include: "current", elements: "tempmax,tempmin,temp" }.freeze

    def initialize(http_client: HTTParty, logger: Rails.logger)
      @http_client = http_client
      @logger = logger
    end

    # Fetch parsed JSON payload for a location. Returns a Hash on success,
    # or nil on failure.
    def fetch(location)
      loc = location.to_s.strip
      return nil if loc.empty?

      return nil unless api_config_present?

      resp = @http_client.get(build_url(loc))

      parse_response(resp, loc)
    rescue StandardError => e
      @logger.error("Weather::Client fetch failed: #{e.class} #{e.message}")
      nil
    end

    private

    def api_key
      ENV["WEATHER_VISUAL_CROSSING_API_KEY"] || Figaro.env.WEATHER_VISUAL_CROSSING_API_KEY
    end

    def base_url
      ENV["WEATHER_VISUAL_CROSSING_URL"] || Figaro.env.WEATHER_VISUAL_CROSSING_URL
    end

    def api_config_present?
      return true if api_key.present? && base_url.present?

      @logger.warn("Weather::Client configuration missing: set WEATHER_VISUAL_CROSSING_API_KEY and WEATHER_VISUAL_CROSSING_URL")
      false
    end

    def build_url(location)
      encoded = URI.encode_www_form(DEFAULT_PARAMS)
      "#{base_url}/#{URI.encode_www_form_component(location)}?key=#{api_key}&#{encoded}"
    end

    def parse_response(resp, location)
      return nil unless resp&.respond_to?(:code)

      if resp.code == 200
        JSON.parse(resp.body)
      else
        @logger.warn("Weather::Client HTTP error for #{location}: #{resp.code}")
        nil
      end
    end
  end
end
