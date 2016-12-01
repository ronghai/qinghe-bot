require 'mail'

_options = { :address             => ENV["BOT_SMTP_ADDRESS"] || "taihu.qinghetech.com",
            :port                 => ENV["BOT_SMTP_PORT"] || 587,
            :domain               => ENV["BOT_SMTP_DOMAIN"] || 'taihu.qinghetech.com',
            :user_name            => ENV["BOT_SMTP_USER"],
            :password             => ENV["BOT_SMTP_PASSWORD"],
            :authentication       => 'plain',
            :enable_starttls_auto => true  }
Mail.defaults do
  delivery_method :smtp, _options
end