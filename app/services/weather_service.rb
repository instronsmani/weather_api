# app/services/weather_service.rb
class WeatherService
  DEFAULT_CACHE_EXPIRES_IN = 30.minutes
  CACHE_KEY_PREFIX = "weather_by_location"

  def initialize(location:, client: Weather::Client.new, formatter: Weather::Formatter, cache: Rails.cache, logger: Rails.logger)
    @location = location.to_s.strip
    @client = client
    @formatter = formatter
    @cache = cache
    @logger = logger
  end

  # Public: Fetch weather details for a location.
  # Returns a hash: { data: { ... }, cached: true/false } or { error: 'code' }
  def fetch
    return { error: "invalid_location" } if @location.blank?

    key = cache_key(@location)

    if @cache.exist?(key)
      data = @cache.read(key)
      return { data: data, cached: true }
    end

    payload = @client.fetch(@location)
    return log_and_return(:weather_api_error, "empty response for #{@location}") if payload.blank?
    formatted = @formatter.format(payload)

    return { error: "format_error" } if formatted.blank?

    rounded = round_values(formatted)
    @cache.write(key, rounded, expires_in: DEFAULT_CACHE_EXPIRES_IN)
    { data: rounded, cached: false }
  rescue StandardError => e
    @logger.error("WeatherService exception: #{e.class} #{e.message}")
    { error: "internal_error" }
  end

  private

  def cache_key(location)
    "#{CACHE_KEY_PREFIX}:#{location.downcase}"
  end

  def round_values(hash)
    hash.transform_values { |v| v.is_a?(Numeric) ? v.round : v }
  end

  def log_and_return(error_key, message = nil)
    @logger.error("WeatherService: #{message}") if message
    { error: error_key.to_s }
  end
end
