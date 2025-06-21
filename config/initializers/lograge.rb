# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true

  config.lograge.custom_options = lambda do |event|
    # Add a timestamp to every log line
    { time: Time.now }
  end

  # Output logs in JSON format
  config.lograge.formatter = Lograge::Formatters::Json.new
end
