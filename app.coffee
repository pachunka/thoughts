
# This is a very incomplete proof of concept. Have fun!

modw3 = require 'web3'
modw3s = require 'web3.storage'
modfs = require 'fs'
modos = require 'os'
modpath = require 'path'
modhttp = require 'http'

configActual = JSON.parse(String(modfs.readFileSync("CONFIGME.json")));

securitybreach = yes
datesplitter = 1000 * 60 * 60 * 24 * 30
volumesplitter = 128

if not configActual["web3storage-api-key"]
	throw new Error "Drop your web3.storage API key into CONFIGME.json to get started."
w3s = new modw3s.Web3Storage token:configActual["web3storage-api-key"]
web3 = new modw3

#client_web3 = "https://cdn.ethers.io/lib/ethers-5.2.umd.min.js"
#client_web3 = "https://bafybeic3siupzfwsrnl2zbrwaxwm22egf6o74jsfqgw32y7vczvxf2lf6m.ipfs.dweb.link/ethers.js"
#client_web3 = "https://cdn.jsdelivr.net/npm/web3@1.5.1/dist/web3.min.js"
client_web3 = "https://bafybeibyqta32y3tpcrn6z7suf6dpwgt3saw6kwkal2pfbqo4hteqztoqm.ipfs.dweb.link/web3.js"

# testing
queueMicrotask ->
	#console.log "Let's have a look",Object.keys(modw3)
	#lst = await  w3s.list({maxResults:10})
	#`for await (const item of lst) {`
	#chk = await item
	#console.log "Maybe",chk
	#`}`
	return

# helpers
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

# actual
modhttp.createServer hanandle = (req, res) ->
	return ender res,400,'..' if req.url.match /\.\./ # no dot-dot requests, anywhere
	rp = decodeURI req.url
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
		res.write """
			<!doctype html>
			<meta charset=utf-8>
			<style>
			:root { font:medium sans-serif }
			</style>
			<script src="#{ OK.attr client_web3 }"></script>
			Anything posted here will live on IPFS forever.
			<br><br>
			<input type=button value="Connect Wallet" onclick="
				ethereum.request({ method: 'eth_requestAccounts' }).then(offerPostAs)
			">
			<script>
			var web3 = new Web3(ethereum);
			function attrOK (ss) {
				return String(ss).replace(/&/g, '&#x26;').replace(/'/g, '&#x27;').replace(/"/g, '&#x22;');
			}
			function offerPostAs (addr) {
				document.body.innerHTML = `
					<textarea autofocus></textarea>
					<br>
					<input addr="${ attrOK(addr) }" type="button" value="Post as ${ attrOK(addr) }" onclick="postAs(this.getAttribute('addr'))">
				`
			}
			function postAs(addr) {
				var txt = document.querySelector('textarea').value;
				//
				//
				web3.eth.personal.sign(web3.utils.fromUtf8(txt),addr,function (err,ans) {
					if (err) throw new Error(err);
					var xh = new XMLHttpRequest;
					xh.open('put','/post/'+addr+'/'+ans);
					//
					xh.onabort = xh.onload = xh.onerror = ev => {
						console.info("EVL:",ev.type,xh.status,xh.statusText,ev);
					}
					//
					xh.send(txt);
				});
			}
			</script>
		"""
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
			# Check it:
			send = String(stored)
			if /[`\\<]/.test send
				console.warn "Skipped sending contents of",fn,"through text/html due to possible injection."
				return ender res,503,"Apparent data corruption."
			#
			# Ready to send:
			res.writeHead 200,
				'Content-Type': 'text/html'
				'Cache-Control':"max-age=#{ 0 }"
				'Access-Control-Allow-Origin': '*'
			res.write """
				<!doctype html>
				<meta charset=utf-8>
				<style>
				:root { font:medium sans-serif }
				</style>
				<body>
				<script>
				function attrOK (ss) {
					return String(ss).replace(/&/g, '&#x26;').replace(/'/g, '&#x27;').replace(/"/g, '&#x22;');
				}
				//
				customElements.define('ipfs-thought',class extends HTMLElement {
					constructor () {
						super();
						this.style.border = '1px solid';
						this.style.borderRadius = '4px';
						this.style.display = 'inline-block';
						this.style.margin = '1em';
						this.style.padding = '1em';
						console.log('boo')
					}
					static get observedAttributes() { return ['cid'] }
					attributeChangedCallback(nm,ol,nu) {
						console.log('yay')
						;(async () => {
							if (!/[a-zA-Z0-9]/.test(nu)) throw new Error("Bad CID:" + nu);
							let url = `https://${ nu }.ipfs.dweb.link/thought.txt`;
							console.log("Gonna go get",url);
							let ftc = await fetch(url);
							let txt = await ftc.text();
							this.textContent = txt
						})();
					}
				});
				//
				const lines = `#{ send }`.trim().split('\\n');
				document.body.insertAdjacentHTML(
					 'beforeEnd'
					,lines
						.filter(ln => /^\\/post /.exec(ln))
						.map(ln => `<ipfs-thought cid="${ attrOK(ln.substr(6).trim()) }"></ipfs-thought>`)
						.join('')
				);
				</script>
			"""
			res.end()
		return
	#else
	#
	return ender res,400,"Not available."
.listen configActual["www-port"]


# auto-reload for cmd line stuff
wayout = no
modfs.watch '.',(tx,fn) ->
	console.log """Hit! "#{tx}" / "#{fn}" """
	if tx is 'change' and not wayout
		if (
			#(securitybreach and (fn.match(/\.js$/) or fn.match(/\.xhtml$/))) or
			(securitybreach and fn.match /\bapp\.js$/) or
			(fn.match /\bbump\.uid$/)
		)
			wayout = yes
			console.log '[[omw]]'
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
