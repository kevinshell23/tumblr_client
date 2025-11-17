require 'json'
require 'faraday'
require 'faraday/multipart'
require 'simple_oauth'

module Tumblr
  module Connection

    class OAuthMiddleware < Faraday::Middleware
      def initialize(app, credentials)
        super(app)
        @credentials = credentials.compact
      end

      def call(env)
        if credentials?
          env.request_headers['Authorization'] = authorization_header(env)
        end
        @app.call(env)
      end

      private

      def credentials?
        @credentials && !@credentials.empty?
      end

      def authorization_header(env)
        SimpleOAuth::Header.new(env.method, env.url, signature_params(env), @credentials).to_s
      end

      def signature_params(env)
        params = env.params ? env.params.dup : {}
        params.merge!(body_params(env))
        params
      end

      def body_params(env)
        return {} unless env.body.is_a?(Hash)
        return {} if env.body.values.any? { |value| multipart_value?(value) }

        env.body
      end

      def multipart_value?(value)
        value.is_a?(Faraday::Multipart::FilePart) || value.is_a?(Faraday::UploadIO)
      end
    end

    class JsonMiddleware < Faraday::Middleware
      def on_complete(env)
        content_type = env.response_headers['content-type']
        return unless content_type && content_type.match?(%r{\bjson\b})
        return unless env.body.is_a?(String) && !env.body.empty?

        env.body = JSON.parse(env.body)
      rescue JSON::ParserError
        # leave body untouched if parsing fails
      end
    end

    def connection(options={})
      options = options.clone

      default_options = {
        :headers => {
          :accept => 'application/json',
          :user_agent => "tumblr_client/#{Tumblr::VERSION}"
        },
        :url => "#{api_scheme}://#{api_host}/"
      }

      client = Faraday.default_adapter
      auth_credentials = credentials.compact

      Faraday.new(default_options.merge(options)) do |conn|
        conn.request OAuthMiddleware, auth_credentials unless auth_credentials.empty?
        conn.request :multipart
        conn.request :url_encoded
        conn.response JsonMiddleware
        conn.adapter client
      end
    end

  end
end
