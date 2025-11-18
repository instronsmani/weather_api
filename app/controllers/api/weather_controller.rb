module Api
  class WeatherController < ApplicationController
    before_action :validate_weather_params

    def show
      location = permitted_params[:location].presence
      service = WeatherService.new(location: location)
      result = service.fetch

      if result[:error]
        render json: { error: result[:error] }, status: :bad_gateway
      else
        render json: { data: result[:data], cached: result[:cached] }, status: :ok
      end
    end

    private

    def validate_weather_params
      if permitted_params[:location].blank?
        render json: { error: 'Location Parameter is missing' }, status: :unprocessable_entity
      end
    end

    def permitted_params
      params.permit(:location)
    end
  end
end
