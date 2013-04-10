require 'castanet/testing'

module Castanet::Testing
  module Namespacing
    def namespaces(chain, &block)
      if chain.empty?
        block.call
      else
        namespace chain.shift do
          namespaces(chain, &block)
        end
      end
    end
  end
end
