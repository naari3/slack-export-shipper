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
    def ship(logdir)
      host = options[:host] || ENV['ES_HOST']
      channel = options[:channel] || ENV['TARGET_CHANNEL']

      shipper = SlackGijiroku::Shipper.new(logdir, host)

      if channel.nil?
        shipper.ship
      else
        shipper.ship_channel(channel)
      end
    end

    desc 'record', 'transfer realtime logs to elasticsearch'
    option :token, required: true
    option :host
    def record
      token = options[:token] || ENV['HUBOT_SLACK_TOKEN']
      host = options[:host] || ENV['ES_HOST']

      recorder = SlackGijiroku::Recorder.new(token, host)
      recorder.rtm_start!
    end
  end
end
