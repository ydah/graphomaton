# frozen_string_literal: true

require 'uri'

class Graphomaton
  class UrlPolicy
    LINK_SCHEMES = %w[http https mailto].freeze
    ASSET_SCHEMES = %w[https].freeze
    CONTROL_CHARACTERS = /[\u0000-\u001f\u007f]/

    def self.validate(value, context: 'URL', schemes: LINK_SCHEMES, allow_windows_path: false)
      url = value.to_s
      unless valid?(url, schemes: schemes, allow_windows_path: allow_windows_path)
        raise SecurityError, "Unsafe #{context}: #{value.inspect}"
      end

      url
    end

    def self.validate_asset(value, context: 'asset URL')
      validate(value, context: context, schemes: ASSET_SCHEMES, allow_windows_path: true)
    end

    def self.valid?(url, schemes: LINK_SCHEMES, allow_windows_path: false)
      return false if url.empty? || url != url.strip
      return false if url.match?(CONTROL_CHARACTERS) || url.start_with?('//')
      return true if allow_windows_path && url.match?(/\A[A-Za-z]:[\\\/]/)
      return false if url.include?('\\')

      uri = URI.parse(url)
      return true unless uri.scheme

      schemes.include?(uri.scheme.downcase)
    rescue URI::InvalidURIError
      false
    end

    private_class_method :valid?
  end
end
