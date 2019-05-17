# frozen_string_literal: true

require 'thor'

require 'slack_gijiroku/shipper'

module SlackGijiroku
  # definition some CLI
  class CLI < Thor
    desc 'ship /path/to/logs', 'transfer exported logs to elasticsearch'
    option :host
    option :channel
    def ship(logdir)
      host = options[:host] || 'localhost:9200'
      channel = options[:channel]

      shipper = SlackGijiroku::Shipper.new(logdir, host)

      if channel.nil?
        shipper.ship
      else
        shipper.ship_channel(channel)
      end
    end
  end
end
