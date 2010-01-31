#!/usr/bin/env ruby
# -*- coding: euc-jp -*-
# $Id$

require "kconv"
require "date"
require "uri"
require 'net/http'

def get_inlinkdata_yahoo( url, params )
   params[ :appid ] = "ECMlhUPV34Hz1amgTZcd8L2JP068rt7mOWZEojROFiZAcNQ7RgCuapU1DRg6WbE-"
   params[ :query ] = url
   query = params.map{|k,v| "#{ k }=#{ v }" }.join( "&" )
   #open( "http://search.yahooapis.com/SiteExplorerService/V1/inlinkData?#{ query }" ){|io| io.read }
   http = Net::HTTP.new( "search.yahooapis.com", 80 )
   response = http.get( "/SiteExplorerService/V1/inlinkData?#{ query }" )
   response.body
end

def get_inlinkdata_total( url )
   inlinks = 0
   url = URI.parse( url ) if not url.respond_to?( :path )
   url.path = "" if url.path.empty? or url.path == "/"
   file_u = url.to_s.gsub( /\W+/, "_" ) + ".xml"
   if File.exist?( file_u )
      xml = open( file_u ){|io| io.read }
   else
      xml = get_inlinkdata_yahoo( url,
                                  { :omit_inlinks => :subdomain,
                                     :entire_site => 1 } )
   end
   inlinks = $1.to_i if xml =~ /\btotalResultsAvailable="(\d+)"/m
   if not File.exist?( file_u )
      open( file_u, "w" ){|io|
         io.puts xml
      }
   end
   if not url.path.empty?
      url.path = ""
      inlinks_subdomain = get_inlinkdata_total( url ) / 10.0
      #p [ url.to_s,  inlinks_subdomain ]
      inlinks += inlinks_subdomain
   end
   inlinks
end

if $0 == __FILE__
   require "optparse"
   format = :tsv
   opt = OptionParser.new
   opt.on('--format VAL') {|v|
      format = v.intern
   }
   opt.parse!(ARGV)
   data = []
   names = []
   ARGV.each do |f|
      #STDERR.puts f
      io = open( f )
      lines = io.readlines.map{|e| e.chomp.split( /\t/ ) }
      name1 = lines.assoc( "機関名称（日）".tosjis )
      name2 = lines.assoc( "機関リポジトリ名称（日）".tosjis )
      name = name1
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
      inlinks = get_inlinkdata_total( url )
      #p inlinks
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
      #puts "growth_rate: #{ growth_rate1 }"
      data << [ name,
                size,
                growth_rate1,
                growth_rate2,
                growth_rate3,
                Math.log( inlinks ) ]
      names << [ name, url ]
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
      case format
      when :wiki
         puts [ "",
                "[[#{ line[0] }|#{ names.assoc( line[0] )[1] }]]",
                "%0.01f" % ( sum * 100 ),
                "%0.02f" % ( d[0] / weight[0] ),
                "%0.02f" % (( d[1] / weight[1] + d[2] / weight[2] + d[3] / weight[3] ) / 3 ),
                "%0.02f" % ( d[4] / weight[4] ),
              ].join( "\t" )
      else
      #when :tsv
         puts [ line[0], "%0.01f" % ( sum * 100 ), d.map{|e| "%0.04f" % e } ].join( "\t" )
      end
   end
end
