require 'rubygems/package'
require 'zlib'

require 'itamae'

require_relative 'checked_http_request'

module Itamae
  module Plugin
    module Resource
      class ExtractHttpArchive < Itamae::Plugin::Resource::CheckedHttpRequest
        class MissingArchiveEntry < StandardError; end

        define_attribute :format, type: Symbol, default: :auto
        define_attribute :path_in_archive, type: String, required: true

        def fetch_content
          content = super

          format = if attributes.format == :auto
            if attributes.url.end_with? '.tar.gz' or attributes.url.end_with? '.tgz' or attributes.content.start_with? "\x1F\x8B"
              :tgz
            else
              raise UnknownFormat, 'Unable to determine archive format'
            end
          else
            attributes.format
          end

          case format
          when :tgz
            tar = Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(content)))
            content = tar.each do |entry|
              if entry.full_name == attributes.path_in_archive
                break entry.read
              end
            end
            tar.close
          else attributes.format != :tgz
            raise UnknownFormat, "Unknown archive format: #{attributes.format}"
          end

          content or raise MissingArchiveEntry, "`#{attributes.path_in_archive}` not found in archive"
        end
      end
    end
  end
end
