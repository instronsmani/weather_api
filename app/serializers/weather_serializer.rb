class WeatherSerializer
  def initialize(data, cached:)
    @data = data
    @cached = cached
  end

  def as_json(*)
    {
      data: {
        tempMax: @data['tempMax'],
        tempMin: @data['tempMin'],
        tempCurrent: @data['tempCurrent']
      },
      cached: @cached
    }
  end
end
