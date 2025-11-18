module Api
  class WeatherController < ApplicationController
    def show
      location = params[:location].presence || params[:id].presence
      service = WeatherService.new(location: location)
      result = service.fetch

      if result[:error]
        render json: { error: result[:error] }, status: :bad_gateway
      else
        render json: { data: result[:data], cached: result[:cached] }, status: :ok
      end
    end
  end
end
