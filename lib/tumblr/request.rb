require 'json'

module Tumblr
  module Request

    # Perform a get request and return the raw response
    def get_response(path, params = {})
      connection.get do |req|
        req.url path
        req.params = params
      end
    end

    # get a redirect url
    def get_redirect_url(path, params = {})
      response = get_response path, params
      if response.status == 301
        response.headers['Location']
      else
        parse_response_body(response.body)['meta']
      end
    end

    # Performs a get request
    def get(path, params={})
      respond get_response(path, params)
    end

    # Performs post request
    def post(path, params={})
      if Array === params[:tags]
        params[:tags] = params[:tags].join(',')
      end
      response = connection.post do |req|
        req.url path
        req.body = params unless params.empty?
      end
      #Check for errors and encapsulate
      respond(response)
    end

    # Performs put request
    def put(path, params={})
      if Array === params[:tags]
        params[:tags] = params[:tags].join(',')
      end
      response = connection.put do |req|
        req.url path
        req.body = params unless params.empty?
      end
      respond(response)
    end

    # Performs delete request
    def delete(path, params={})
      response = connection.delete do |req|
        req.url path
        req.body = params unless params.empty?
      end
      respond(response)
    end

    def respond(response)
      body = parse_response_body(response.body)
      if [201, 200].include?(response.status)
        body['response']
      else
        # surface the meta alongside response
        res = body['meta'] || {}
        res.merge! body['response'] if body['response'].is_a?(Hash)
        res
      end
    end

    def parse_response_body(body)
      return body if body.is_a?(Hash)
      return {} if body.nil? || (body.respond_to?(:empty?) && body.empty?)

      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end

  end
end
