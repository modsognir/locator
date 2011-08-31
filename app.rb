require 'sinatra'
require 'rspec'
require 'rack/test'
require 'haml'
require 'redis'
require 'multi_json'

$db = Redis.new

module Helpers
  def encode(object)
    ::MultiJson.encode(object)
  end

  def decode(object)
    return unless object

    begin
      ::MultiJson.decode(object)
    rescue ::MultiJson::DecodeError => e
      raise DecodeException, e
    end
  end

  def push(obj)
    $db.sadd "locator:devices", encode(obj)
  end
end

class Locator < Sinatra::Base
  include Helpers

  get '/' do
    @devices = $db.smembers('locator:devices').map {|d| decode(d) }
    haml :index
  end

  post '/' do
    # $db.flushall
    push({
        :name => params[:name],
        :lat  => params[:lat],
        :long => params[:long],
        :time => params[:time]
      })
  end
end



describe Locator do
  include Rack::Test::Methods

  def app
    @app ||= Locator
  end

  def db
    @db ||= Redis.new
  end

  after(:each) { puts last_response.body }

  it "should get" do
    get '/'
    last_response.body.should include "Locator"
  end

  it "should be able to post a location" do
    post '/', :name => "modsognir-1", :lat => 10.1, :long => 29.7, :time => Time.new(2011,10,1,1,1,1)
    get '/'
    last_response.body.should include "modsognir-1"
    last_response.body.should include "10.1, 29.7"
    last_response.body.should include "2011-10-01 01:01:01 +1000"
  end
end

Locator.run!