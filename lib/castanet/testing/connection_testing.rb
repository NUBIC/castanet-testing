require 'castanet/testing'
require 'logger'
require 'net/http'
require 'openssl'
require 'uri'

module Castanet::Testing
  module ConnectionTesting
    LOGGER = Logger.new($stderr)

    def responding?(url, logger = LOGGER)
      uri = URI(url)

      begin
        h = Net::HTTP.new(uri.host, uri.port)
        h.use_ssl = (uri.scheme == 'https')
        h.verify_mode = OpenSSL::SSL::VERIFY_NONE
        resp = h.get(uri.request_uri)
        code = resp.code.to_i

        (200..399).include?(code)
      rescue => e
        logger.debug "#{url}: #{e.class} (#{e.message})"
        false
      end
    end
  end
end
