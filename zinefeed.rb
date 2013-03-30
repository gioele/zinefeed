#!/usr/bin/ruby

require 'erb'
require 'feedzirra'
require 'readability'
require 'open-uri'
require 'eeepub'
require 'pp'

TMPDIR = '/tmp/book/'

TAGS = %w[div p h1 h2 h3 h4 h5 h6 header] +
       %w[a em strong span] +
       %w[q blockquote] +
       %w[img ul ol li] + 
       %w[table tr th td]
ATTRS = %w[src href alt]

WORDS = {
	'en' => {
		:title => 'Title page',
		:toc => 'Table of contents',
	},
	'de' => {
		:title => 'Titelblatte',
		:toc => 'Inhaltsverzeichnis',
	},
	'it' => {
		:title => 'Copertina',
		:toc => 'Indice',
	}
}

def make_book
	`mkdir -p #{TMPDIR}`

	url = $ARGV[0]
	if $ARGV[1] == '--days'
		days = $ARGV[2].to_i
	end
	days ||= 7

	language = 'de'

	feed = fetch_feed(url)
	entries = select_entries(feed.entries, days)
	
	book = book_info(feed, language)
	$title = "title.html"
	$toc = "toc.html"
	$pages = []
	$images = []
	
	make_title(book)
	make_articles(entries)
	make_toc(book, entries)
	
	filename = book[:title_complete] + '.epub'

	save_epub(filename, book, entries)

	puts "Book generated: `#{filename}`"
end

def fetch_feed(url)
	feed = Feedzirra::Feed.fetch_and_parse(url)

	pp feed.url
	pp feed.feed_url
	pp feed.title
	pp feed.last_modified

	return feed
end

def book_info(feed, language)
	date = feed.last_modified
	if date.nil?
		warn "Could not extract date from feed; using current date"
		last_date = Time.now
	end

	book_date = date.strftime("%Y-%m-%d")
	interval_short = book_date # TODO: use proper date interval
	interval_long = book_date # TODO: make a localized version for cover
	book_title = feed.title
	book_title_complete = feed.title + ", " + interval_short
	book_author = feed.title # TODO: find a better alternative
	book_id = feed.feed_url + '/' + book_date
	book_uid = 'zinefeed-' + book_id.gsub(/[^a-zA-Z0-9\-.]/, '-') + '-' + Time.now.to_i.to_s

	info = {
		:title => book_title,
		:title_complete => book_title_complete,
		:language => language,
		:author => book_author,
		:date => book_date,
		:interval_short => interval_short,
		:interval_long => interval_long,
		:identifier => book_id,
		:uid => book_uid,
	}

	return info
end

def make_html(title, content, page_class)
	template_file = 'data/page.html.erb'

	renderer = ERB.new(open(template_file).read)
	html = renderer.result(binding)

	return html
end

def clean_page(entry)
	article = open(entry.url).read
	doc = Readability::Document.new(article, :tags => TAGS, :attributes => ATTRS)

	content = doc.content

	if !content.include?('<h1')
		content = "<h1>#{entry.title.strip}</h1>\n" + content
	end

	remote_images = content.scan(/src=['"]([^'"]+)['"]/).flatten

	remote_images.each do |img_url|
		local_img = File.basename(img_url)
		$images << local_img

		File.open(TMPDIR + local_img, 'w') do |img|
			img << open(img_url).read
		end

		content.sub!(img_url, local_img)
	end

	return content
end


def select_entries(entries, days)
	# TODO: retain if entry.day in range (entry.first.day - days)
	num_good_entries = days
	return entries.first(num_good_entries)
end


def make_title(book)
	File.open(TMPDIR + $title, 'w') do |file|
		content =<<END
<h1><span id="title">#{book[:title]}</span> <span id="date">#{book[:date]}</span></h2>
<p id="interval">#{book[:interval_long]}</p>
END

		file << make_html(book[:title_complete], content, 'titlepage')
	end
end

def make_toc(book, entries)
	File.open(TMPDIR + $toc, 'w') do |file|
		toc_word = WORDS[book[:language]][:toc]
		page_title = toc_word + " " + book[:title_complete]

		content = "<h1>#{toc_word}</h1><h2>#{book[:title_complete]}</h2>"

		entries.each_with_index do |entry, idx|
			content +=<<END
<div class="article">
<p class="title"><a href="#{$pages[idx]}">#{entry.title.strip}</a></p>
<p class="author">#{entry.author.strip}, #{entry.published.strftime("%Y-%m-%d")}</p>
<p class="summary">#{entry.summary.strip}</p>
</div>
END
		end

		file << make_html(page_title, content, 'toc')
	end
end

def make_articles(entries)
	entries.each do |entry|
		content = clean_page(entry)
	
		article_slug = File.basename(entry.url)
		page = "#{article_slug}.html"
		File.open(TMPDIR + page, 'w') do |file|
			file << make_html(entry.title.strip, content, 'article')
		end
	
		$pages << page
	end
end

def save_epub(filename, book, entries)
	pieces = [$title, $toc] + $pages + $images
	all_files = pieces.map { |pag| TMPDIR + pag } + [ 'data/zinefeed.css' ]

	lang = book[:language]

	chapters = [
		{ :label => WORDS[lang][:title], :content => $title, :type => 'cover'},
		{ :label => WORDS[lang][:toc], :content => $toc, :type => 'toc' },
	] + entries.each_with_index.map do |entry, idx|
		{
			:label => entry.title.strip,
			:content => $pages[idx],
		}
	end
		
	chapters[2][:type] = 'text'

	epub = EeePub.make do
		title book[:title_complete]
	
		language   book[:language]
		creator    book[:author]
		date       book[:date]
		identifier book[:identifier], :scheme => 'URL'
		uid        book[:uid]
	
		files all_files
		nav chapters
		guide chapters.first(3)
	end
	
	epub.save(filename)
end


make_book

