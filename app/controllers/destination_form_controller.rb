class DestinationFormController < ApplicationController
  require 'net/https'
  require 'uri'
  require 'json'
  require 'time'

  def new
  end

  def create
    @q1 = params[:q1]
    @q2 = params[:q2]
    array = [@q1, @q2]
    @array_2 = []
    array.each do |d|
      @uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=東京駅&destinations='+d+'&mode=driving&key=AIzaSyDqllFb4Hk7607Vye2ExMPhLRlEm3dlnSw')
      uri = URI.parse(@uri)
      json = Net::HTTP.get(uri)
      @result = JSON.parse(json)
      @array_2.push(@result)
    end
    
    @distance = []
    @array_2.each do |d|
      @distance.push(d['rows'][0]['elements'][0]['distance']['text'])
    end

    



    # @uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=東京駅&destinations='+@q1+'&mode=driving&key=AIzaSyDqllFb4Hk7607Vye2ExMPhLRlEm3dlnSw')
    # @uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=東京駅&destinations='+@q2+'&mode=driving&key=AIzaSyDqllFb4Hk7607Vye2ExMPhLRlEm3dlnSw')
    # uri = URI.parse(@uri)
    # json = Net::HTTP.get(uri)
    # @result = JSON.parse(json)
    # @time = @result['rows'][0]['elements'][0]['distance']['text']
  end

end


