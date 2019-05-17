# frozen_string_literal: true

require_relative 'lib/slack_gijiroku'

desc '[bundle exec] rake ship logdir=/path/to/unzipped/logs [host=localhost:9200] [channel=general]'
task :ship do
  # elasticsearch's host address
  host = ENV['host'] || 'localhost:9200'
  shipper = SlackGijiroku::Shipper.new(ENV['logdir'], host)

  if ENV['channel'].nil?
    shipper.ship
  else
    shipper.ship_channel(ENV['channel'])
  end
end
