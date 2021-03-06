
require './lolita'

Lita.configure do |config|
  # The name your robot will use.
  config.robot.name = "lolita"

  # The locale code for the language to use.
  # config.robot.locale = :en

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = :debug

  # An array of user IDs that are considered administrators. These users
  # the ability to add and remove other users from authorization groups.
  # What is considered a user ID will change depending on which adapter you use.
  # config.robot.admins = ["1", "2"]

  # The adapter you want to connect with. Make sure you've added the
  # appropriate gem to the Gemfile.
  config.robot.adapter = :slack

  config.adapters.slack.token = ENV["SLACK_TOKEN"]

  ## Example: Set options for the chosen adapter.
  # config.adapter.username = "myname"
  # config.adapter.password = "secret"
  #puts config.adapters.slack.token
  ## Example: Set options for the Redis connection.
  config.redis[:url] = ENV["REDISCLOUD_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379"
  #puts "redis url #{config.redis[:url]}"
  #unless config.redis[:url]
  #  config.redis[:url] = ENV["REDISTOGO_URL"]
  #end
  #puts "redis url #{config.redis[:url]}"
  #unless config.redis[:url]
  #  config.redis[:url] = "redis://127.0.0.1:6379"
  #end
  
  if Lita::env?(:production)
    config.http.port = ENV["PORT"]
  end
  
  #puts config.redis[:url]
  
  #config.redis[:url] = ENV["REDISTOGO_URL"]

  # config.redis.port = 1234

  ## Example: Set configuration for any loaded handlers. See the handler's
  ## documentation for options.
  # config.handlers.some_handler.some_config_key = "value"
end
