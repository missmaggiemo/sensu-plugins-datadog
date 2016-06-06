#! /usr/bin/env ruby
#
#   datadog-metrics
#
# DESCRIPTION:
#
# OUTPUT:
#   metric data
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
#   Copyright 2013 Katherine Daniels (kd@gc.io)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-handler'
require 'dogapi'

#
# Datadog Metrics
#
class DatadogMetrics < Sensu::Handler
  # Override filters from Sensu::Handler.
  # They are not appropriate for metric handlers
  #
  def filter
  end

  # Create a handle and event set
  #
  def handle
    @dog = Dogapi::Client.new(settings['datadog']['api_key'], settings['datadog']['app_key'])
    emit_metric(@event['check']['name'], @event['check']['status'], @event['client']['name'], @event['check']['executed'])
  end

  # Push metric point
  #
  # @param name       [String]
  # @param value      [String]
  # @param _timestamp [String]
  def emit_metric(name, value, host, _timestamp)
    Timeout::timeout(3) do
      puts "datadog -- sending metric name: #{name}, value: #{value}, host: #{host}"
      @dog.emit_point(name, value, host: host)
    end
  # Raised when any metrics could not be sent
  #
  rescue Timeout::Error
    puts 'datadog -- timed out while sending metrics'
  rescue => error
    puts "datadog -- failed to send metrics: #{error.message}"
    puts " #{error.backtrace.join("\n\t")}"
  end
end
