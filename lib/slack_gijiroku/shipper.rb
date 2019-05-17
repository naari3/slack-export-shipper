# frozen_string_literal: true

require 'date'
require 'elasticsearch'
require 'fileutils'
require 'json'
require 'logger'
require 'ruby-progressbar'

module SlackGijiroku
  # transfer slack extracted logs to elasticsearch
  class Shipper
    def initialize(logdir, host, index_prefix: 'slack', workspace: '')
      @logger = Logger.new(STDOUT)

      @logdir = logdir
      @es = Elasticsearch::Client.new(host: host, request_timeout: 180)
      @index_prefix = index_prefix
      @workspace = workspace
      @batch_size = 500
    end

    def ship
      channels.each do |channel|
        ship_channel(channel)
      end
    end

    def ship_channel(channel)
      @logger.info("shipping \"#{channel}\"")

      channel_messages = load_channel(channel)
      docs = aggregate(channel_messages, channel_name: channel)
      bulk_index(docs)
    end

    def users
      @users ||= JSON.parse(File.open("#{@logdir}/users.json"))
      @users
    end

    def userid2name(id)
      user = users.find { |i| i['id'] == id }
      user.nil? ? id : user['name']
    end

    def name2userid(name)
      user = users.find { |i| i['name'] == name }
      user.nil? ? nil : user['id']
    end

    def channels
      @channels ||= Dir.entries(@logdir).select do |i|
        File.directory?(File.join(@logdir, i)) && ['.', '..'].include?(i).!
      end

      @channels
    end

    def load_channel(channel_name)
      channel = {}

      Dir.entries("#{@logdir}/#{channel_name}").each do |i|
        next if ['.', '..'].include?(i)

        channel[i.chomp('.json')] = JSON.parse(
          File.open("#{@logdir}/#{channel_name}/#{i}")
        )
      end

      channel
    end

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
      total = docs.values.inject(0) { |m, i| m + i.size }
      pb = ProgressBar.create(total: total, format: '|%B| %c/%C')

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

        next unless bulk_body.size > @batch_size

        @es.bulk(body: bulk_body) if bulk_body.size > @batch_size
        pb.progress += bulk_body.size
        bulk_body = []
      end

      @es.bulk body: bulk_body unless bulk_body.empty?
      pb.progress += bulk_body.size
    end
  end
end
