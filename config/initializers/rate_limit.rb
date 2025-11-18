# config/initializers/rate_limit.rb

require "rack/ratelimit"

# In-memory rate limit store for development/testing.
# For production, consider using Redis or another persistent store.
class SimpleRateLimitStore
  def initialize
    @request_timestamps = Hash.new { |h, k| h[k] = [] }
  end

  # Tracks requests per key and period.
  # Returns the current count within the period.
  def increment(key, period)
    # Validate period is an Integer (seconds). Reject nil or other types early
    raise TypeError, "period must be an Integer number of seconds" unless period.is_a?(Integer)

    now = Time.now.to_i
    timestamps = @request_timestamps[key]
    # Remove timestamps outside the period
    timestamps.reject! { |timestamp| timestamp <= now - period }
    timestamps << now
    timestamps.size
  end
end

Rails.application.config.middleware.use(
  Rack::Ratelimit,
  name: "weather_details_api",
  conditions: ->(env) {
    env["REQUEST_METHOD"] == "GET" && env["REQUEST_PATH"].include?("/api/weather")
  },
  rate: [
    Figaro.env.WEATHER_DETAILS_API_LIMIT.to_i,
    Figaro.env.WEATHER_DETAILS_API_LIMIT_PERIOD_SECS.to_i.seconds
  ],
  counter: SimpleRateLimitStore.new,
  logger: Rails.logger,
  error_message: "API rate limit exceeded."
) { |env| env["REMOTE_ADDR"] }
