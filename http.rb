# frozen_string_literal: true

# This class is used as a proxy for all outbounding http connection
# coming from callbacks, services and hooks. The direct use of the HTTParty
# is discouraged because it can lead to several security problems, like SSRF
# calling internal IP or services.

class HTTP
  include HTTParty

  default_timeout 5

  BlockedUrlError = Class.new(StandardError)
  RedirectionTooDeep = Class.new(StandardError)

  HTTP_ERRORS = [
    SocketError, OpenSSL::SSL::SSLError, OpenSSL::OpenSSLError,
    Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
    Net::OpenTimeout, Net::ReadTimeout, HTTP::BlockedUrlError,
    HTTP::RedirectionTooDeep, URI::InvalidURIError,
    Net::WriteTimeout
  ].freeze


  def self.perform_request(http_method, path, options, &block)
    retries = options[:retries].to_i
    if retries.positive?
      request_with_retry(retries) { super }
    else
      super
    end
  rescue HTTParty::RedirectionTooDeep
    raise RedirectionTooDeep
  end

  def self.request_with_retry(retries, &block)
    times_retried = 0

    begin
      yield(block)
    rescue *HTTP_ERRORS => _e
      if times_retried < retries
        times_retried += 1
        sleep(1) unless Rails.env.test?
        retry
      else
        false
      end
    end
  end
end
