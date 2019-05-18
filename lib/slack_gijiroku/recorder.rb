# frozen_string_literal: true

require 'elasticsearch'
require 'memoist'
require 'slack-ruby-client'

require 'pry'

module SlackGijiroku
  # transfer slack extracted logs to elasticsearch
  class Recorder
    extend Memoist

    def initialize(token, host, index_prefix: 'slack', workspace: '')
      @logger = Logger.new(STDOUT)

      Slack.configure do |conf|
        conf.token = token
      end

      @rtm_client = rtm_client
      @web_client = web_client

      @es = Elasticsearch::Client.new(host: host, request_timeout: 180)

      @index_prefix = index_prefix
      @workspace = workspace
    end

    def rtm_client
      rtm_client = Slack::RealTime::Client.new
      rtm_client.on :hello do
        puts "Successfully connected, welcome '#{rtm_client.self.name}' to the '#{rtm_client.team.name}' team at https://#{rtm_client.team.domain}.slack.com."
      end
      rtm_client.on :message do |data|
        transfer_message(data)
      end
      rtm_client
    end

    def rtm_start!
      @rtm_client.start!
    end

    def web_client
      Slack::Web::Client.new
    end

    def transfer_message(data)
      channel_id = data['channel']
      channel_name = @web_client.channels_info(channel: channel_id)['channel']['name']
      doc = aggregate({ messages: [data.to_h] }, channel_name: channel_name)
      p doc
      bulk_index(doc)
    end

    def channelid2name(id)
      @web_client.channels_info(channel: id)['channel']['name']
    end
    memoize :channelid2name

    def userid2name(id)
      @web_client.users_info(user: id)['user']['name']
    end
    memoize :userid2name

    # regroup by local date for elasticsearch's indexing
    def aggregate(channel_messages, channel_name: '')
      docs = {}

      channel_messages.values.flatten.each do |i|
        ts = i['ts'].to_f
        datetime = Time.at(ts).to_datetime
        index = datetime.strftime("#{@index_prefix}-%Y.%m.%d")

        i['@timestamp'] = datetime.to_s

        # I am adding these two here in order to avoid using scripted fields in Kibana
        i['hour_of_day'] = datetime.hour
        i['day_of_week'] = datetime.wday

        i['user_name'] = userid2name(i['user']) unless i['user'].nil?
        i['channel_name'] = channel_name unless channel_name.empty?
        i['workspace'] = @workspace unless @workspace.empty?

        docs[index] ||= []
        docs[index] << i
      end

      docs
    end

    def bulk_index(docs)
      bulk_body = []

      docs.each do |index, messages|
        messages.each do |message|
          bulk_body << {
            index: {
              _index: index,
              _type: 'slack-message',
              data: message
            }
          }
        end
      end

      @es.bulk body: bulk_body
    end
  end
end
