
# This is a very incomplete proof of concept. Have fun!

modw3 = require 'web3'
modw3s = require 'web3.storage'
modfs = require 'fs'
modos = require 'os'
modpath = require 'path'
modhttp = require 'http'

configActual = JSON.parse(String(modfs.readFileSync("CONFIGME.json")));

#
# Web3
if not configActual["web3storage-api-key"]
	throw new Error "Drop your web3.storage API key into CONFIGME.json to get started."
w3s = new modw3s.Web3Storage token:configActual["web3storage-api-key"]
web3 = new modw3

#
# Testing
queueMicrotask ->
	#console.log "Let's have a look",Object.keys(modw3)
	#lst = await  w3s.list({maxResults:10})
	#`for await (const item of lst) {`
	#chk = await item
	#console.log "Maybe",chk
	#`}`
	return

#
# Themes
readThemeSync = (theme) ->
	throw new Error("Theme name sanity check.") if /\.\//.test theme
	#
	snipRead = (snip,ext = 'html') ->
		try
			return String modfs.readFileSync("themes/#{theme}/#{snip}.#{ext}")
		catch ee
			if ee.code is 'ENOENT'
				return String modfs.readFileSync("themes/fallback/#{snip}.#{ext}")
			throw ee
	#
	return
		"sys-prelude":  snipRead 'sys-prelude'
		"sys-style":    snipRead 'sys-style'
		"sys-header":   snipRead 'sys-header'
		"page-home":    snipRead 'page-home'
		"page-profile": snipRead 'page-profile'

themeActual = readThemeSync configActual['theme']

#
# Helpers
OK =
	attr: (ss) -> String(ss).replace(/&/g, '&#x26;').replace(/'/g, '&#x27;').replace(/"/g, '&#x22;')
	html: (ss) -> String(ss).replace(/&/g, '&#x26;').replace(/</g, '&#x3C;')
ender = (res,code,more) ->
	res.writeHead code,
		'Content-Type':'text/plain'
		'Access-Control-Allow-Origin': '*'
	res.write "#{code}\n"
	res.write "\n#{more}\n" if more
	res.end()

#
# Main
console.log ["         -= Thought Server on " + modos.hostname() + " =-         "]

declareNewPost = (type,addr,cid,ocb) ->
	if addr.match /\./
		throw new Error "Filename compromised: #{addr}"
	if addr.match /[^a-zA-Z0-9]/
		throw new Error "CID compromised: #{cid}"
	fn = "db/#{addr}.sw"
	#
	#console.log "yay new post for",addr,"-",cid,"\\o/"
	step2 = (initial) ->
		#
	modfs.readFile fn,(er,stored) ->
		initial = null
		if er
			switch er.code
				when 'ENOENT'
					# brand new file
					initial = ''
				else
					console.error er
					ocb?(no)
					throw new Error "File access problems on #{fn}"
		else
			initial = String(stored)
		#
		# step 2
		lines = initial.split '\n'
		lines.unshift "/post #{ cid }"
		modified = lines.join '\n'
		#
		
		#
		modfs.writeFile fn,modified,(er) ->
			if er
				console.error "Writing problems",er
				ocb?(no)
				throw new Error "Saving is Broken: #{fn}"
			ocb?(yes)

#
# Actual
modhttp.createServer hanandle = (req, res) ->
	return ender res,400,'..' if req.url.match /\.\./ # no dot-dot requests, anywhere
	rp = decodeURI req.url
	hst = req.headers.host.split(':')[0]
	#
	rp = rp.split('?')[0]
	rp = "#{rp}index.html" if rp.match /\/$/
	#
	pth = rp.split '/'
	pth = pth.map (ss) -> ss.toLowerCase()
	console.log pth
	return ender res,400,"Peculiar path." if pth[0]
	#
	if req.method is 'PUT'
		if not (match = rp.match /^\/post\/0x([0-9A-Fa-f]{40})\/0x([0-9A-Fa-f]{130})$/)
			console.log rp,"ain't puttable."
			return ender res,405,"Put the sword away."
		[_,addr,siggy] = match
		#
		ttl = 0
		gather = []
		bad = no
		req.on 'data',(intake) ->
			if bad
				if ttl > 0x4000
					req.connection.destroy()
				return
			gather.push String(intake)
			ttl += intake.length
			if ttl > 0x400
				bad = yes
		#req.pipe ws
		req.on 'end',() ->
			if bad
				return ender res,413,"tl;dw"
			bdy = gather.join ''
			console.log "Happily received #{addr}, and",bdy
			#
			try
				signer = web3.eth.accounts.recover(bdy,"0x"+siggy);
			catch ee
				console.warn "web3 hates it:",siggy
				return ender res,400,"Dubious signature error."
			console.log signer,"vs.",addr
			if signer.toLowerCase() isnt "0x"+addr.toLowerCase()
				console.log "IMPOSTOR"
				return ender res,401,"Sloppy signature error."
			#else
			console.log "All Clear"
			#
			thf = new modw3s.File [bdy],"thought.txt"
			sif = new modw3s.File [JSON.stringify eth:addr,sig:siggy],"verify.json"
			console.log "Here it goes.."
			said = no
			try
				await w3s.put [thf,sif],
					name: "Thought from #{addr}"
					onRootCidReady: (cid) -> declareNewPost 'post',addr,cid
					#onStoredChunk: ->
				ender res,204,""
			catch ee
				console.warn "Upload likely didn't happen. declareNewPost was called prematurely.",ee
				ender res 502,"Upload was not possible."
		return
	#
	if pth[1] is ".well-known" # add more of these if you want traditional file passthrough serving
		modfs.readFile rp,(er,cn) ->
			if er then return switch er.code
				when 'ENOENT'
					console.log req.connection.remoteAddress,"404'd",rp
					ender res,404
				else
					console.log req.connection.remoteAddress,"500'd",rp
					ender res,500,er.code
			res.writeHead 200,
				'Content-Type': 'application/octet-stream'
				'Cache-Control':"max-age=#{ 0 }"
			res.write cn
			res.end()
		return
	else if pth.length is 2 and pth[1] is  'index.html'
		res.writeHead 200,
			'Content-Type': 'text/html'
			'Cache-Control':"max-age=#{ 0 }"
			'Access-Control-Allow-Origin': '*'
		res.write [
			themeActual['sys-prelude']
			themeActual['sys-style']
			themeActual['sys-header'].replace /ACF98A03-C0AD-4498-98B9-871F88BE477B/g, hst
			themeActual['page-home']
		].join '\n'
		res.end()
		return
	else if pth.length is 3 and pth[1].match /[a-z0-9]{40}/
		fn = "db/#{pth[1]}.sw"
		#
		modfs.readFile fn,(er,stored) ->
			if er
				switch er.code
					when 'ENOENT'
						# no such home
						return ender res,404,"No such number."
					else
						console.error "File access problems",er
						return ender res,500,"Something is not right."
			#
			# Overzealously disallow characters that could cause code injection
			send = String(stored)
			if /[`\\<"&]/.test send
				console.warn "Skipped sending contents of",fn,"through text/html due to possible injection."
				return ender res,503,"Apparent data corruption."
			#
			# Ready to send:
			res.writeHead 200,
				'Content-Type': 'text/html'
				'Cache-Control':"max-age=#{ 0 }"
				'Access-Control-Allow-Origin': '*'
			res.write [
				themeActual['sys-prelude']
				themeActual['sys-style']
				themeActual['sys-header'].replace /ACF98A03-C0AD-4498-98B9-871F88BE477B/g, hst
				themeActual['page-profile'].replace /ADF26198-411C-414A-9EB3-2C981305110E/g, send
			].join '\n'
			res.end()
		return
	#else
	#
	return ender res,400,"Not available."
.listen configActual["www-port"]


# auto-reload for cmd line stuff
wayout = no
modfs.watch '.',(tx,fn) ->
	return if wayout
	if tx is 'change'
		console.log """Root file changed: "#{tx}" / "#{fn}" """
		if (
			# Restart server when either of these files changes:
			(fn.match /\bapp\.js$/i) or
			(fn.match /\bconfigme\.json$/i) or
			(fn.match /\bbump\.uid$/i)
		)
			wayout = yes
			console.log '-- Reboot --'
			#!!#md_save()
			probably_shut_it_down()
try modfs.watch './themes/',(recursive:yes),(tx,fn) ->
	return if wayout
	if tx is 'change'
		console.log """Theme file changed: "#{tx}" / "#{fn}" """
		if (
			# Restart server when either of these files changes:
			(fn.match /\.html$/i) or
			(fn.match /\.css$/i)
		)
			wayout = yes
			console.log '-- Reboot --'
			#!!#md_save()
			probably_shut_it_down()

# I feel like I'm gonna ctrl-c absent-mindedly and lose a bunch of data some time
seriously = 0
process.on 'SIGINT',->
	seriously += 1
	switch seriously
		when 1 then console.log("First Ctrl-C absorbed. 2 to go.")
		when 2 then console.log("Last Ctrl-C absorbed. Next terminates.")
		when 4
			console.log("Impolitely terminating.")
			process.exit 92
		else
			console.log("Politely terminating.")
			#!!#md_save()
			probably_shut_it_down()


sys_pending_shutdown = no
probably_shut_it_down = ->
	#!!#if busy_saving
	#!!#	sys_pending_shutdown = yes
	#!!#else
	shut_it_down()
shut_it_down = ->
	setTimeout(->
		if seriously >= 3 
			process.exit 90
		else
			process.exit 99
	,125)
