include RbConfig

require 'rubygems' if CONFIG['host_os'].start_with? "darwin"
require 'date'
require 'optparse'
require 'fileutils'
require 'uri'

begin
  require 'feedzirra'
  require 'reverse_markdown'
rescue GEM::LoadError
  puts "BOOM! Please install the `feedzirra` and `reverse_markdown` gems first."
  return
end

def parse_post_entries(feed, verbose)
  posts = []
  feed.entries.each do |post|
    obj = Hash.new
    created_datetime = post.published
    creation_date = Date.parse(created_datetime.to_s)
    title = post.title
    path = creation_date.to_s + "-" + title.gsub(/[^0-9A-Za-z\s]/i, '').split(/  */).join("-").delete('\/').downcase
    FileUtils.mkdir_p("articles/" + path)
    file_name = path + "/index.md"
    content = ReverseMarkdown.parse(post.summary)
    
    obj["file_name"] = file_name
    obj["url"] = post.url
    obj["title"] = title
    obj["author"] = post.author
    obj["creation_datetime"] = created_datetime
    obj["updated_datetime"] = post.updated
    obj["content"] = content
    obj["categories"] = post.categories.join(" ")
    posts.push(obj)
  end
  return posts
end

def write_posts(posts, verbose)
  dir = "articles/"
  Dir.mkdir(dir) unless File.directory?(dir)

  total = posts.length, i = 1
  posts.each do |post|
    file_name = dir + post["file_name"]
    path = URI(post["url"]).path
    header = %{---
title: #{post["title"].gsub(':','-')}
date: #{post["creation_datetime"]}
categories: #{post["categories"]}
author: #{post["author"]}
aliases: ['#{path}']
template: article.jade
---

}
    File.open(file_name, "w+") {|f|
      f.write(header)
      f.write(post["content"])
      f.close
    }

    if verbose
      puts "  [#{i}/#{total[0]}] Written post #{file_name}"
      i += 1
    end
  end
end

def main
  options = {}
  opt_parser = OptionParser.new do |opt|
    opt.banner = "Usage: ./blogger_to_jekyll.rb FEED_URL [OPTIONS]"
    opt.separator ""
    opt.separator "Options"

    opt.on("-v", "--verbose", "Print out all.") do
      options[:verbose] = true
    end
  end

  opt_parser.parse!

  if ARGV[0]
    feed_url = ARGV.first
  else
    puts opt_parser
    exit()
  end

  puts "Fetching feed #{feed_url}..."
  feed = Feedzirra::Feed.fetch_and_parse(feed_url)

  puts "Parsing feed..."
  posts = parse_post_entries(feed, options[:verbose])

  puts "Writing posts to articles/..."
  write_posts(posts, options[:verbose])

  puts "Done!"
end

main()
