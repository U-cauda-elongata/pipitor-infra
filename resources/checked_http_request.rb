require 'digest'

require 'itamae'

module Itamae
  module Plugin
    module Resource
      class CheckedHttpRequest < Itamae::Resource::HttpRequest
        class ChecksumMismatch < StandardError; end

        define_attribute :checksum, type: String

        def fetch_content
          content = super

          if attributes.sha256
            sha256 = Digest::SHA256.hexdigest(content)
            unless sha256 == attributes.sha256
              raise ChecksumMismatch, "expected `sha256:#{attributes.sha256}`, got `sha256:#{sha256}"
            end
          end

          content
        end
      end
    end
  end
end
