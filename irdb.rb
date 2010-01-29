#!/usr/bin/env ruby
# -*- coding: euc-jp -*-
# $Id$

require "kconv"
require "date"
require "open-uri"

data = []
ARGV.each do |f|
   io = open( f )
   lines = io.readlines.map{|e| e.chomp.split( /\t/ ) }
   name = lines.assoc("機関リポジトリ名称（日）".tosjis)[1]
   url  = lines.assoc("機関リポジトリへのリンク（日）".tosjis)[1]
   url.sub!( /\/index\.(?:jsp|html?)$/, "/" )
   url.sub!( /portal$/, "/" )
   file_u = url.gsub( /\W+/, "_" ) + ".xml"
   if File.exist?( file_u )
      xml = open( file_u ){|io| io.read }
   else
      xml = open( "http://search.yahooapis.com/SiteExplorerService/V1/inlinkData?appid=YahooDemo&query=#{ url }&omit_inlinks=domain" ){|io| io.read }
   end
   if xml =~ /totalResultsAvailable="(\d+)"/m
      inlinks = $1.to_i
      if not File.exist?( file_u )
         open( file_u, "w" ){|io|
            io.puts xml
         }
      end
   end
   #p inlinks
   date = lines.assoc( "本公開日".tosjis )[1]
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
   data << [ name, size, growth_rate1, growth_rate2 / growth_rate1, growth_rate3 / growth_rate1, Math.log( inlinks ) ]
end
#puts data

weight = [ 0.25, 0.05, 0.1, 0.1, 0.5 ]
max_data = []
( data[0].size - 1 ).times do |i|
   max_data[i] = data.map{|e| e[i+1] }.max
end

data.each_with_index do |line, idx|
   #puts line[0]
   sum = 0
   line[1..-1].each_with_index do |e, i|
      j = weight[i] * e / max_data[i]
      sum += j
   end
   puts [ line[0], sum ].join( "\t" )
end
