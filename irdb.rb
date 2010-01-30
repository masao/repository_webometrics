#!/usr/bin/env ruby
# -*- coding: euc-jp -*-
# $Id$

require "kconv"
require "date"
require "uri"
require "open-uri"

data = []
ARGV.each do |f|
   #STDERR.puts f
   io = open( f )
   lines = io.readlines.map{|e| e.chomp.split( /\t/ ) }
   name = lines.assoc("機関リポジトリ名称（日）".tosjis)
   if name.nil?
      STDERR.puts "name not found: skipping #{ f }"
      next
   end
   name = name[1]
   url  = lines.assoc("機関リポジトリへのリンク（日）".tosjis)[1]
   #puts url
   url.sub!( /\/index\.(?:jsp|html?)(?:\?[\w\=]*)?$/, "/" )
   #url.sub!( /\/repo_index\.html?$/, "/" )
   #url.sub!( /\/Index\.e$/, "/" )
   url.sub!( /portal$/, "/" )
   #puts url
   url = URI.parse( url )
   if url.path == "/"
      url.path = ""
      entire_site = "&entire_size=1"
   end
   url = url.to_s
   file_u = url.gsub( /\W+/, "_" ) + ".xml"
   inlinks = 0
   if File.exist?( file_u )
      xml = open( file_u ){|io| io.read }
   else
      xml = open( "http://search.yahooapis.com/SiteExplorerService/V1/inlinkData?appid=YahooDemo&query=#{ url }&omit_inlinks=subdomain#{ entire_site }" ){|io| io.read }
   end
   if xml =~ /\btotalResultsAvailable="(\d+)"/m
      inlinks = $1.to_i
      if not File.exist?( file_u )
         open( file_u, "w" ){|io|
            io.puts xml
         }
      end
   end
   #p inlinks
   #p url
   date = lines.assoc( "本公開日".tosjis )[1]
   date = lines.assoc( "試験公開日".tosjis )[1] if date.nil? or date.empty?
   date = Date.new( *date.split( /\D/ ).map{|e| e.to_i } )
   #p date.to_s
   #p lines.size
   if lines[21][0].toeuc =~ /^［リポジトリ/
      while lines[21].size != 0
         #p lines[21]
         lines.delete_at( 21 )
      end
      lines.delete_at( 21 )
      lines.delete_at( 21 )
      #p lines[21]
   end
   month = lines[21..-1]
   #p month
   #p month[0][-1]
   #p month[12][-1]
   size = month[0][-1].to_i
   growth_rate1 = size / ( Date.today - date ).to_f
   growth_rate2 = ( size - month[12][-1].to_i ) / 365.0
   growth_rate2 = 0 if growth_rate2 < 0
   growth_rate3 = ( size - month[6][-1].to_i ) / 182.5
   growth_rate3 = 0 if growth_rate3 < 0
   #puts "size: #{ size }"
   #puts "growth_rate: #{ growth_rate }"
   data << [ name,
             size,
             growth_rate1,
             growth_rate2,
             growth_rate3,
             Math.log( inlinks ) ]
end
#puts data

weight = [ 0.25, 0.05, 0.1, 0.1, 0.5 ]
max_data = []
( data[0].size - 1 ).times do |i|
   #p data.map{|e| e[i+1] }
   #p data.map{|e| e[i+1] }.max
   max_data[i] = data.map{|e| e[i+1] }.max
end
#p max_data

data.each_with_index do |line, idx|
   #puts line[0]
   d = []
   line[1..-1].each_with_index do |e, i|
      d << weight[i] * e / max_data[i]
   end
   sum = d.inject(0){|e,sum| sum += e }
   puts [ line[0], "%0.01f" % ( sum * 100 ), d.map{|e| "%0.04f" % e } ].join( "\t" )
end
