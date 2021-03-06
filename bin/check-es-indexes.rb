#! /usr/bin/env ruby
#
# Check Elastic Search Indexes
# ===
#
# DESCRIPTION:
#   This plugin will check a a node for dupe indexes
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# needs usage
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Yieldbot, Inc  <devops@yieldbot.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'

#
# == Check Elastic Search Cluster Index
#
class CheckESClusterIndex < Sensu::Plugin::Check::CLI
  option :cluster,
         description: 'Array of clusters to check',
         short: '-C CLUSTER[,CLUSTER]',
         long: '--cluster CLUSTER[,CLUSTER]',
         proc: proc { |a| a.split(',') }

  option :ignore,
         description: 'Comma separated list of indexes to ignore',
         short: '-i INDEX[,INDEX]',
         long: '--ignore INDEX[,INDEX]',
         proc: proc { |a| a.split(',') }

  option :debug,
         description: 'Debug',
         short: '-d',
         long: '--debug'

  option :skip_verify,
         on: :tail,
         boolean: true,
         description: 'Skip TLS certificate verification (not recommended!)',
         long: '--insecure-skip-tls-verify'

  option :cert_file,
         on: :tail,
         description: 'Cert file to use',
         long: '--cert-file CERT'

  option :curl_options,
         on: :tail,
         description: 'additional options to curl command',
         long: '--curl-options OPTIONS'

  def run
    # If only one cluster is given, no need to check the indexes
    ok 'All indexes are unique' if config[:cluster].length == 1
    curl_command = 'curl -s'
    if config[:skip_verify]
      curl_command += ' --insecure'
    end
    if config[:cert_file]
      curl_command += " --cacert #{config[:cert_file]}"
    end
    if config[:curl_options]
      curl_command += " #{config[:curl_options]} "
    end

    port = ':9200'
    cmd = '/_cat/indices?v | tail -n +2'

    valid_index = {}
    dupe_index = {}
    config[:cluster].each do |u|
      index_arr = `#{ curl_command } #{ u }#{ port }#{ cmd }`.split("\n")
      index_arr.each do |t|
        t = t.split[1]

        # If the index is in the ignore list, go to the next one
        next if config[:ignore].include? t

        if valid_index.key?(t)
          dupe_index[t] = [] unless dupe_index[t].is_a?(Array)
          dupe_index[t] << u
          dupe_index[t] << valid_index[t] unless dupe_index[t]
                                                 .include?(valid_index[t])
        else
          valid_index[t] = [] unless valid_index[t].is_a?(Array)
          valid_index[t] << u
        end
      end
    end

    if dupe_index.count > 0
      dupe_index.each do |k, v|
        critical "#{k} is on #{v}"
      end
    else
      ok 'All indexes are unique'
    end
  end
end
