require 'spec_helper'

require 'cgi'
require 'fakeweb'
require 'filepath'

describe Zinefeed do
	before(:all) do
		FakeWeb.allow_net_connect = false
		fixdir = __FILE__.as_path / '..' / 'fixtures'
		fixdir.files.each do |file|
			uri = CGI.unescape(file.to_s)
			FakeWeb.register_uri(:get, uri, :response => file.read)
		end
	end

	let(:url_simple) { 'http://www.freitag.de/RSS' }

	describe "#select_entries" do
		it "selects exactly 5 days of news" do
			zf = Zinefeed.new
			feed = zf.fetch_feed(url_simple)
	                entries = zf.select_entries(feed.entries, 5)
			entries.should have(12).items
		end

		it "accepts to be asked for more days than available" do
			zf = Zinefeed.new
			feed = zf.fetch_feed(url_simple)
	                entries = zf.select_entries(feed.entries, 30)
			entries.should have(50).items
		end
	end
end
