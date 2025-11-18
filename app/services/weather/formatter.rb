module Weather
  class Formatter
    def self.format(payload)
      return nil if payload.blank?

      day = payload.dig("days", 0)
      current = payload.dig("currentConditions", "temp")
      return nil unless day.present? && current.present?

      {
        "tempMax" => day["tempmax"],
        "tempMin" => day["tempmin"],
        "tempCurrent" => current
      }
    end
  end
end
