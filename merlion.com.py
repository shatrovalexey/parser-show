import sys
# from fake_useragent import UserAgent as FakeUserAgent

( hostName , serverPort ) = sys.argv[ 1:: ]
serverPort = int( serverPort )

js_path = 'psgi/b2b.merlion.com.js'
clientNo = 'XXX'
clientLogin = 'XXX'
clientPassword = 'XXX'
host = 'b2b.merlion.com'
proto = 'https'
origin = '%s://%s' % ( proto , host )
# fua = FakeUserAgent( )
# ua = fua.random
ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36'

procName = '%s-%d' % ( host , serverPort )

from psutil import process_iter

for ps in process_iter( [ 'name' , ] ) :
	if ps.info[ 'name' ] == procName :
		sys.exit( 0 )

from setproctitle import setproctitle as setProcTitle

setProcTitle( procName )

from selenium import webdriver
from selenium.webdriver import ChromeOptions , DesiredCapabilities
from seleniumwire.webdriver import Chrome
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
from time import sleep
import json
import os
import re
from http.server import BaseHTTPRequestHandler , HTTPServer
from urllib.parse import urlsplit , parse_qs
from signal import signal , SIGPIPE , SIGINT , SIGCHLD , SIGTERM , SIG_IGN , SIG_DFL

options = ChromeOptions( )
options.add_argument( '--headless' )
options.add_argument( '--profile-directory=pySelenium' )
options.add_argument( '--disable-popup-blocking' )
options.add_argument( '--disable-default-apps' )
options.add_argument( '--disable-dev-shm-usage' )
options.add_argument( '--disable-gpu' )
options.add_argument( '-no-sandbox' )
options.add_argument( '--disable-infobars' )
options.add_argument( '--dns-prefetch-disable' )
options.add_argument( '--disable-extensions' )
options.add_argument( '--disable-notifications' )
options.add_argument( '--ignore-certificate-errors-spki-list' )
options.add_argument( '--ignore-certificate-errors' )
options.add_argument( '--ignore-ssl-errors' )
options.add_argument( '--allow-insecure-localhost' )
options.add_argument( '--ignore-urlfetcher-cert-requests' )
options.add_argument( 'User-Agent=%s' % ua )
options.add_argument( 'Accept-Encoding=gzip, deflate, br' )
options.add_experimental_option( 'prefs' , { 'profile.managed_default_content_settings.images' : 2 , } )

desired_capabilities = options.to_capabilities( )
desired_capabilities[ 'acceptInsecureCerts' ] = True
desired_capabilities[ 'acceptSslCerts' ] = True

driver = ChromeDriverManager( ).install( )
driver = Chrome( driver , options = options , desired_capabilities = desired_capabilities )

def at_exit( * args , ** kwargs ) :
	driver.quit( )
	sys.exit( 0 )

signal( SIGINT | SIGPIPE | SIGTERM , at_exit )
signal( SIGCHLD , SIG_IGN )

def warn( * args ) :
	print( * args , file = sys.stderr )

def wait( fn ) :
	for i in range( 400 ) :
		try :
			return fn( )
		except :
			sleep( 0.01 )
	return None

def get( by , selector , ctx = None ) :
	if not ctx :
		ctx = driver

	return wait( lambda : ctx.find_element( by , selector ) )

def first( result , * keys ) :
	for key in keys :
		if ( key in result ) and result[ key ] :
			return result[ key ]
	else :
		return None

authorization = None

def auth( ) :
	j = 0
	global authorization

	driver.get( origin )

	if authorization :
		try :
			driver.find_element( By.CSS_SELECTOR , '[data-testid="logout"]' )
		except :
			pass
		else :
			return authorization

	while ( j < 10 ) :
		try :
			form = get( By.CSS_SELECTOR , '.loginContainer > form' )
			get( By.CSS_SELECTOR , '[name="clientNo"]' , form ).send_keys( clientNo )
			get( By.CSS_SELECTOR , '[name="clientLogin"]' , form ).send_keys( clientLogin )
			get( By.CSS_SELECTOR , '[name="password"]' , form ).send_keys( clientPassword )
			form.submit( )

			result = driver.wait_for_request( '/api/settings' ).headers[ 'authorization' ]

			if not result :
				raise Exception( 'не удалось авторизоваться' )

			return result
		except ( BrokenPipeError , IOError , Exception ) as exception :
			warn( exception )
			j += 1
			driver.get( origin )

		sleep( 0.05 )

authorization = auth( )
script = open( js_path , 'r' ).read( )

# {"name":"Unauthorized","message":"Your request was made with invalid credentials.","code":0,"status":401}

class LocalServer( BaseHTTPRequestHandler ) :
	def do_GET( self ) :
		query = urlsplit( self.path ).query

		if not query :
			return self.send_error( 403 )

		query = parse_qs( query )

		if 'query' not in query :
			return self.send_error( 403 )

		results = [ ]

		global authorization
		i = 0
		j = 0

		while ( i < len( query[ 'query' ] ) ) and ( j < 5 ) :
			try :
				query_item = query[ 'query' ][ i ]
				result = driver.execute_script( script , authorization , query_item )

				if type( result ) is dict :
					raise Exception( result[ 'error' ] )

				for result_item in result :
					result_item[ 'query' ] = query_item

				results += result
				i += 1
			except Exception as exception :
				warn( exception )

				try :
					data = json.loads( '%s' % exception )

					if ( 'status' in data ) and ( data.status != 200 ) :
						authorization = auth( )
				except Exception as exception :
					warn( exception )
				
				j += 1

		response = {
			'error' : None ,
			'query' : '|' . join( query[ 'query' ] ) ,
			'origin' : origin ,
			'host' : host ,
			'data' : [ ] ,
		}

		for result in results :
			response[ 'data' ].append( {
				'query' : [ result[ 'query' ] , ] ,
				'host' : host ,
				'name' : result[ 'Short Name' ] ,
				'title' : first( result ,'name' , 'Short Name' , 'Extra Name' ) ,
				'art' : first( result , 'vendorPart' , 'vendorId' ) ,
				'brand' : result[ 'brand' ] ,
				'price' : result[ 'priceRUB_NEW' ] ,
				'quantity' : {
					'value' : result[ 'availableMSK1_NEW' ] ,
					'availability' : result[ 'AvailableToday' ] ,
					'free' : result[ 'AvailableToday' ] ,
					'transit' : result[ 'transitReserveAvail_NEW' ] ,
				} ,
				'href' : '%s/products/card/%s' % ( origin , result[ 'id' ] , ) ,
				'image' : '%s%s' % ( origin , result[ 'imageUrl' ] , ) ,
			} )

		self.send_response( 200 )
		self.send_header( 'Content-type' , 'application/json' )
		self.end_headers( )

		self.wfile.write( bytes( json.dumps( response ) , 'utf-8' ) )

webServer = HTTPServer( ( hostName , serverPort ) , LocalServer )
warn( 'Server started http://%s:%s' % ( hostName , serverPort ) )

try :
	webServer.serve_forever( )
except ( KeyboardInterrupt , Exception ) :
	webServer.server_close( )
	driver.quit( )