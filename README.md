# Weather Details API

A small Rails API that exposes weather details for a given location. This README documents the newly added functionality (Task 1), what changed, how to configure and run the service, the API contract, error cases, caching and rate-limiting behavior, and pointers for testing and production hardening.

Table of contents
- Overview
- Main changes (files added/modified)
- API: endpoint, parameters and responses
- Configuration / environment variables
- Caching behavior
- Rate limiting
- Logging and errors
- Testing notes
- Production recommendations

## Overview

This feature provides a single endpoint that returns three aggregate weather values for a given location:
- tempMax (daily maximum)
- tempMin (daily minimum)
- tempCurrent (current temperature)

The implementation is split into:
- an HTTP client for the upstream weather API,
- a formatter for extracting the three values,
- a service that handles caching, rounding, error handling and logging,
- a controller that exposes the endpoint,
- a lightweight rate limit initializer and in-memory counter for development,
- a serializer class for consistent JSON structure.

## Main changes (files added / modified)

- app/controllers/api/weather_controller.rb
  - Exposes GET /api/weather?location=<location>
  - Validates presence of `location` param
  - Calls `WeatherService` and returns JSON with appropriate HTTP status codes

- app/services/weather_service.rb
  - Coordinates fetching, formatting, caching and rounding
  - Cache key: `weather_by_location:<location.downcase>`
  - Default cache expiration: 30 minutes
  - Returns a hash: either `{ data: {...}, cached: true/false }` or `{ error: "<error_key>" }`
  - Error keys used: `invalid_location`, `weather_api_error`, `format_error`, `internal_error`

- app/services/weather/client.rb
  - Weather::Client performs the HTTP request to the upstream Visual Crossing (or configured) weather provider
  - Uses configurable `DEFAULT_PARAMS` to request `current` and the elements `tempmax,tempmin,temp`
  - Reads base URL and API key from environment (or Figaro)
  - Returns parsed JSON on success or nil on failure
  - Logs warnings / errors for missing config or non-200 responses

- app/services/weather/formatter.rb
  - Weather::Formatter.format(payload) extracts:
    - payload.dig("days", 0)["tempmax"] -> "tempMax"
    - payload.dig("days", 0)["tempmin"] -> "tempMin"
    - payload.dig("currentConditions", "temp") -> "tempCurrent"
  - Returns a hash with string keys ("tempMax", "tempMin", "tempCurrent") or nil if payload isn't usable

- app/serializers/weather_serializer.rb
  - WeatherSerializer#as_json returns a consistent structure:
    {
      data: {
        tempMax: ...,
        tempMin: ...,
        tempCurrent: ...
      },
      cached: true/false
    }
  - (Note: controller currently renders service output directly; the serializer is provided for consistent formatting if used elsewhere.)

- config/routes.rb (modified)
  - Added namespaced route:
    - GET /api/weather => api/weather#show

- config/initializers/rate_limit.rb
  - Adds Rack::Ratelimit middleware for request throttling
  - A simple in-memory `SimpleRateLimitStore` is provided for development/testing
  - Rate limit values are configured via env (Figaro fallbacks)
  - Middleware condition limits requests to paths including `/api/weather` and GET methods

## API

Endpoint
- GET /api/weather?location=<location>

Notes:
- The endpoint lives under the `/api` namespace:
  - Example: GET /api/weather?location=94103

Request parameters
- location (required) — string: address, postal code, city name, latitude longitude.

Success response (HTTP 200)
- JSON body (example):
```json
{
  "data": {
    "tempMax": 18,
    "tempMin": 11,
    "tempCurrent": 15
  },
  "cached": false
}
```
- `cached` indicates whether the response came from the local cache.

Missing parameter (HTTP 422)
- If `location` param is missing or blank:
```json
{
  "error": "Location Parameter is missing"
}
```

Upstream / internal error responses (HTTP 502)
- If the service layer returns an error (e.g. upstream API failure, formatting error, internal exception), the controller responds with 502 (Bad Gateway) and the error key:
```json
{
  "error": "weather_api_error"
}
```
Possible error keys:
- `invalid_location` — returned by service if invalid/blank location (controller validation prevents this in normal flow)
- `weather_api_error` — upstream fetch returned an empty or nil payload
- `format_error` — payload could not be parsed into expected fields
- `internal_error` — service rescued an unexpected exception

## Configuration / Environment variables

Required
- WEATHER_VISUAL_CROSSING_API_KEY — API key for the upstream weather provider
- WEATHER_VISUAL_CROSSING_URL — Base URL for the upstream weather provider (no trailing slash recommended)

Alternative (if using Figaro)
- Figaro.env.WEATHER_VISUAL_CROSSING_API_KEY
- Figaro.env.WEATHER_VISUAL_CROSSING_URL

Rate limiting configuration (optional, via Figaro or ENV):
- WEATHER_DETAILS_API_LIMIT — number of requests allowed per period (integer)
- WEATHER_DETAILS_API_LIMIT_PERIOD_SECS — period in seconds for the above limit (integer)

Dependencies noted in code
- HTTParty (or any client passed into Weather::Client)
- rack/ratelimit (middleware)
- Figaro (optional; helper fallback is used in code)

## Caching behavior

- Uses Rails.cache (injected into WeatherService, default is Rails.cache).
- Cache key pattern: `weather_by_location:<location.downcase>`
- Default TTL: 30 minutes (DEFAULT_CACHE_EXPIRES_IN)
- When a cache hit occurs, service returns `{ data: <cached_data>, cached: true }`
- When a cache miss occurs, service fetches from upstream, formats, rounds numeric values, writes to cache, then returns `{data: <rounded>, cached: false}`

Rounding
- Numeric values in the formatted hash are rounded by `WeatherService#round_values` (calls `round` on numeric values)

## Rate limiting

- Rack::Ratelimit middleware is configured in config/initializers/rate_limit.rb.
- Middleware condition restricts enforcement to GET requests with path containing `/api/weather`.
- A `SimpleRateLimitStore` is provided as an in-memory counter for development/testing.
  - This store tracks request timestamps per key and returns counts for the configured period.
  - It will not persist across app restarts.
- For production use, replace the counter with a persistent store (Redis, Memcached) to allow multi-process/multi-host coordination.

## Logging and errors

- Weather::Client logs:
  - warnings when API configuration is missing
  - warnings when HTTP status is non-200
  - errors when a fetch raises an unexpected error

- WeatherService logs:
  - error on rescued exceptions with class and message
  - `log_and_return` helper logs messages when necessary and returns an error key

- Rate limit middleware can log when requests exceed the permitted rate.

## Testing notes

- Weather::Client supports dependency injection of the HTTP client (`http_client:`), so you can provide a test double that responds to `.get` and returns an object with `.code` and `.body`.
- WeatherService supports injection of:
  - `client:` (Weather::Client instance or test double),
  - `formatter:` (Weather::Formatter or test double),
  - `cache:` (Rails.cache or a test double),
  - `logger:` (inject test logger)
- Test possible flows:
  - Successful fetch -> formatted -> cached write -> round -> returned result
  - Cache hit path
  - Formatter returns nil -> `format_error`
  - Client returns nil -> `weather_api_error`
  - Rate limit behavior — integration test with Rack middleware (or unit tests for SimpleRateLimitStore)
- Example RSpec pattern:
```ruby
let(:client) { instance_double(Weather::Client, fetch: payload) }
let(:formatter) { class_double(Weather::Formatter, format: formatted_hash) }
let(:cache) { ActiveSupport::Cache::MemoryStore.new }

subject { WeatherService.new(location: '94103', client: client, formatter: formatter, cache: cache, logger: Rails.logger) }
```

## Production recommendations

- Secure the upstream API key:
  - Use Rails encrypted credentials, environment variables injected by your orchestration layer, or a secrets manager instead of Figaro for production.
- Use a production-capable cache:
  - Use Redis or Memcached as Rails.cache.
- Use a persistent distributed rate limit store:
  - Replace SimpleRateLimitStore with a Redis-based counter (e.g., via rack-attack or a Redis-backed limiter) so rate-limits work across processes and hosts.
- Validate and sanitize the `location` input further to avoid injection problems when constructing URLs.
- Add monitoring and alerts on:
  - Upstream HTTP error rates
  - Rate-limit breaches
  - Cache hit/miss ratios
- Consider adding versioning to the API path (`/api/v1/weather`) for future compatibility.
