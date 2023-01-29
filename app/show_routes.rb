require 'sinatra'
require 'sinatra/advanced_routes'

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'app'

SinatraWardenExample.each_route do |route|
  puts '-' * 20
  puts route.app.name   # "SinatraWardenExample"
  puts route.path       # that's the path given as argument to get and akin
  puts route.verb       # get / head / post / put / delete
  puts route.file       # "some_sinatra_app.rb" or something
  puts route.line       # the line number of the get/post/... statement
  puts route.pattern    # that's the pattern internally used by sinatra
  puts route.keys       # keys given when route was defined
  puts route.conditions # conditions given when route was defined
  puts route.block      # the route's closure
end
