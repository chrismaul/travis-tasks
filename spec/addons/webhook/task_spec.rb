require "spec_helper"
require "rack"

describe Travis::Addons::Webhook::Task do
  include Travis::Testing::Stubs

  let(:subject) { Travis::Addons::Webhook::Task }
  let(:http)    { Faraday::Adapter::Test::Stubs.new }
  let(:client)  { Faraday.new { |f| f.request :url_encoded; f.adapter :test, http } }
  let(:payload) { Marshal.load(Marshal.dump(WEBHOOK_PAYLOAD)) }
  let(:repo_slug) { "svenfuchs/minimal" }

  before do
    Travis.config.notifications = [:webhook]
    subject.any_instance.stubs(:http).returns(client)
    subject.any_instance.stubs(:repo_slug).returns(repo_slug)
  end

  def run(targets)
    subject.new(payload, targets: targets, token: "123456").run
  end

  it "posts to the given targets, with the given payload and the given access token" do
    targets = ["http://one.webhook.com/path", "http://second.webhook.com/path"]

    targets.each do |url|
      uri = URI.parse(url)
      http.post uri.path do |env|
        env[:url].host.should == uri.host
        env[:request_headers]["Authorization"].should == authorization_for(repo_slug, "123456")
        payload_from(env).keys.sort.should == payload.keys.map(&:to_s).sort
      end
    end

    run(targets)
    http.verify_stubbed_calls
  end

  context "when request token is invalid" do
    it "raises an error when token is an empty string" do
      expect{
        subject.new(payload, token: "").send(:authorization)
      }.to raise_error(Travis::Addons::Webhook::InvalidTokenError)
    end

    it "raises an error when token is nil" do
      expect{
        subject.new(payload, token: nil).send(:authorization)
      }.to raise_error(Travis::Addons::Webhook::InvalidTokenError)
    end
  end

  it "posts with automatically-parsed basic auth credentials" do
    url = "https://Aladdin:open%20sesame@fancy.webhook.com/path"
    uri = URI.parse(url)
    http.post uri.path do |env|
      env[:url].host.should == uri.host
      auth = env[:request_headers]["Authorization"]
      auth.should == "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ=="
      auth.should == Faraday::Request::BasicAuthentication.header("Aladdin", "open sesame")
      payload_from(env).keys.sort.should == payload.keys.map(&:to_s).sort
    end

    subject.new(payload, targets: [url]).run
    http.verify_stubbed_calls
  end

  it "includes a Travis-Repo-Slug header" do
    url = "https://one.webhook.com/path"
    uri = URI.parse(url)
    http.post uri.path do |env|
      env[:url].host.should == uri.host
      env[:request_headers]["Travis-Repo-Slug"].should == repo_slug
      payload_from(env).keys.sort.should == payload.keys.map(&:to_s).sort
    end

    subject.new(payload, targets: [url], token: "abc123").run
    http.verify_stubbed_calls
  end

  def payload_from(env)
    JSON.parse(Rack::Utils.parse_query(env[:body])["payload"])
  end

  def authorization_for(slug, token)
    Digest::SHA2.hexdigest(slug + token)
  end
end
