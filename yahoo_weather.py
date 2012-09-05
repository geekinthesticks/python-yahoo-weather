#!/usr/bin/python2

##   Copyright (C) 2012 Ian Barton.

##    Author: Ian Barton <ian@manor-farm.org>

##   This program is free software; you can redistribute it and/or modify
##   it under the terms of the GNU General Public License as published by
##   the Free Software Foundation; either version 3, or (at your option)
##   any later version.
##
##   This program is distributed in the hope that it will be useful,
##   but WITHOUT ANY WARRANTY; without even the implied warranty of
##   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##   GNU General Public License for more details.

import urllib, os, sys
from xml.dom import minidom
import time

# The url for the Yahoo 5 day forecast.
WEATHER_URL = 'http://xml.weather.yahoo.com/forecastrss/'

# Code for your location.
# You can get UK locations from:
# http://edg3.co.uk/snippets/weather-location-codes/united-kingdom/
# International codes are available from:
# http://edg3.co.uk/snippets/weather-location-codes/

# Appending _c returns forecast in SI units _f returns forecast in Fahrenheit.
LOCATION = 'UKXX0718_c'

# Url for the Yahoo weather images.
YAHOO_IMAGES_URL = 'http://l.yimg.com/us.yimg.com/i/us/we/52'

# Path where weather icons will be downloaded.
# This must be writeable by the script.
IMAGES_PATH = './images'


def parse_forecast_data(dom):
    daylist = []
    icons = []
    forecast_data = {}

    forecast = dom.getElementsByTagName('yweather:forecast')

    for day in forecast:
    # The weather icons are cached locally to reduce page load time.
    # Get the GIF for the weather if we don't already have it
        weather = {}
        if not os.path.exists(IMAGES_PATH + '/%s.gif' % day.attributes['code'].value):
            print "Getting image.\n"
            urllib.urlretrieve(YAHOO_IMAGES_URL + '/%s.gif' % day.attributes['code'].value, \
                          IMAGES_PATH + '/%s.gif' % day.attributes['code'].value)
        weather = {'Day' : day.attributes['day'].value, 'Low' : day.attributes['low'].value, 'High' : day.attributes['high'].value, 'Text' : day.attributes['text'].value, 'Code' : day.attributes['code'].value}
        daylist.append(weather)

    return daylist

def main():
    # Open the weather url and parse it.
    dom = minidom.parse(urllib.urlopen(WEATHER_URL + LOCATION + '.xml'))
    forecast = parse_forecast_data(dom)
    for day in forecast:
        print "%s\n---\n High: %s Low: %s %s\n" % (day['Day'], day['High'], day['Low'], day['Text'])



    print "lat: %s long %s " % (dom.getElementsByTagName('geo:lat')[0].firstChild.data, dom.getElementsByTagName('geo:long')[0].firstChild.data)

    # Get sunrise and sunset data.
    astro = dom.getElementsByTagName('yweather:astronomy')
    for day in astro:
        print "Sunrise: %s Sunset: %s" % (day.attributes['sunrise'].value, day.attributes['sunset'].value)

if __name__ == '__main__':
    main()
