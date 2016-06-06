#! /usr/bin/env ruby
#
#   datadog-notification
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-handler
#   gem: dogapi
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Sonian, Inc <support@sensuapp.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-handler'
require 'dogapi'

#
# Datadog notifications
#
class DatadogNotif < Sensu::Handler

  # Use our custom filter, and handle the remaining events with datadog
  #
  def handle
    filter
    datadog
  end

  # Only filter disabled or silenced alerts
  #
  def filter
    filter_disabled
    filter_silenced
  end

  # determine the action to take for the event
  def acquire_action
    case @event['action']
    when 'create'
      'error'
    when 'resolve'
      'success'
    end
  end

  # Return a low priotiry for resolve and warn events, normal for critical and unknown
  def acquire_priority
    case @event['status']
    when '0', '1'
      'low'
    when '2', '3'
      'normal'
    end
  end

  # submit the event to datadog
  def datadog
    description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' ')
    action = acquire_action
    priority = acquire_priority
    tags = []
    tags.push('sensu')
    # allow for tags to be set in the configuration, this could be used to indicate environment
    tags.concat(settings['datadog']['tags']) unless settings['datadog']['tags'].nil? && !settings['datadog']['tags'].kind_of(Array)
    # add the subscibers for the event to the tags
    tags.concat(@event['check']['subscribers']) unless @event['check']['subscribers'].nil?
    begin
      Timeout::timeout(3) do
        dog = Dogapi::Client.new(settings['datadog']['api_key'], settings['datadog']['app_key'])
        response = dog.emit_event(Dogapi::Event.new(
                                    description,
                                    msg_title: @event['check']['name'],
                                    tags: tags,
                                    alert_type: action,
                                    priority: priority,
                                    source_type_name: settings['datadog']['source_type_name'],
                                    aggregation_key: @event['check']['name']
        ), host: @event['client']['name'])

        begin
          if response[0] == '202'
            puts "Submitted event to Datadog, name: #{@event['check']['name']}, description: #{description}"
          else
            puts "Unexpected response from Datadog: HTTP code #{response[0]}"
          end
        rescue
          puts "Could not determine whether sensu event was successfully submitted to Datadog: #{response}"
        end
      end
    rescue Timeout::Error
      puts 'Datadog timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end
  end
end
