#!/usr/bin/env ruby
# $Id$

require "kendall.rb"

if ARGV.size != 2
   puts "Usage: #$0 old.txt new.txt"
   exit
end

old = []
open( ARGV[0] ).readlines.map do |l, i|
   old << l.chomp.split( /\|\|/ )
end
new = []
open( ARGV[1] ).readlines.each_with_index do |l, i|
   new << l.chomp.split( /\|\|/ )
end

cases = []
#p old
common_set = old.map{|e| e[2] } & new.map{|e| e[2] }
#p common_set
puts "Common sets: #{ common_set.size }"
[ old, new ].each do |set|
   set.each do |k|
      if not common_set.include? k[2]
         set.delete k
         p "#{k} deleted"
      end
   end
   case_hash = {}
   set.each_with_index do |k,i|
      case_hash[ i+1 ] = k[3].to_f
   end
   cases << case_hash
end
puts "Spearman: #{ spearman( cases[0], cases[1] ) }"
puts "Kendall:  #{ kendall( cases[0], cases[1] ) }"

# cf. http://aoki2.si.gunma-u.ac.jp/JavaScript/corr2.html
#old = cases[0].invert
#new = cases[1].invert
#common_set.each do |k|
#   puts [ old[k], new[k] ].join( "\t" )
#end
