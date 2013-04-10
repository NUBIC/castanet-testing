require 'castanet/testing'

module Castanet::Testing
  module AssetPaths
    def asset_path(p)
      File.expand_path("../../../../assets/#{p}", __FILE__)
    end

    def ssl_key_path
      asset_path('test.key')
    end

    def ssl_cert_path
      asset_path('test.crt')
    end
  end
end
