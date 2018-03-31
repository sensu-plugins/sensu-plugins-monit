# !/usr/bin/env ruby
#
# Checks Monit Service Statuses
# ===
#
# DESCRIPTION:
#   This plugin checks the status of monit
#   servces via the monit HTTP API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   linux
#   bsd
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   example commands
#
# LICENSE:
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'rexml/document'
require 'net/http'

class CheckMonit < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h host',
         default: '127.0.0.1'

  option :port,
         short: '-p port',
         default: 2812

  option :user,
         short: '-U user'

  option :pass,
         short: '-P pass'

  option :uri,
         short: '-u uri',
         default: '/_status?format=xml'

  option :ignore,
         short: '-i ignore',
         default: ''

  option :ignore_unmonitored,
         long: '--ignore-unmonitored',
         short: '-m',
         default: false,
         boolean: true

  def run
    status_doc = REXML::Document.new(monit_status)
    ignored = config[:ignore].split(',')

    status_doc.elements.each('monit/service') do |svc|
      name = svc.elements['name'].text
      monitored = svc.elements['monitor'].text
      status = svc.elements['status'].text

      next if ignored.include? name
      next if monitored == '0' && config[:ignore_unmonitored]
      unknown "#{name} status unkown" unless %w( 1 5 ).include? monitored
      critical "#{name} status failed" unless status == '0'
    end

    ok 'All services OK'
  end

  def monit_status
    res = Net::HTTP.start(config[:host], config[:port]) do |http|
      req = Net::HTTP::Get.new(config[:uri])
      req.basic_auth config[:user], config[:pass] unless config[:user].nil?
      http.request(req)
    end

    unless res.code.to_i == 200
      unknown "Failed to fetch status from #{config[:host]}:#{config[:port]}"
    end

    res.body
  end
end
