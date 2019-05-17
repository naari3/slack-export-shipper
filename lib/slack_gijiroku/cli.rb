# frozen_string_literal: true

require 'thor'

require 'slack_gijiroku/shipper'
require 'slack_gijiroku/recorder'

module SlackGijiroku
  # definition some CLI
  class CLI < Thor
    desc 'ship /path/to/logs', 'transfer exported logs to elasticsearch'
    option :host
    option :channel
    option :index_prefix
    def ship(logdir)
      host = options[:host] || 'localhost:9200'
      channel = options[:channel]
      index_prefix = options[:index_prefix]

      shipper = SlackGijiroku::Shipper.new(logdir, host, index_prefix: index_prefix)

      if channel.nil?
        shipper.ship
      else
        shipper.ship_channel(channel)
      end
    end

    desc 'record', 'transfer realtime logs to elasticsearch'
    option :token, required: true
    option :host
    option :index_prefix
    def record
      token = options[:token]
      host = options[:host] || 'localhost:9200'
      index_prefix = options[:index_prefix]

      recorder = SlackGijiroku::Recorder.new(token, host, index_prefix: index_prefix)
      recorder.rtm_start!
    end
  end
end
