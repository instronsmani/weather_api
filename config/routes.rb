Rails.application.routes.draw do
  namespace :api do
    # Accept GET /api/v1/weather?location=94103 or GET /api/v1/weather/94103
    get 'weather', to: 'weather#show'
    get 'weather/:id', to: 'weather#show'
  end
end
