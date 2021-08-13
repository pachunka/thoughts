// Generated by CoffeeScript 2.5.1
(function() {
  // This is a very incomplete proof of concept. Have fun!
  var OK, configActual, declareNewPost, ender, hanandle, modfs, modhttp, modos, modpath, modw3, modw3s, probably_shut_it_down, readThemeSync, seriously, shut_it_down, sys_pending_shutdown, themeActual, w3s, wayout, web3;

  modw3 = require('web3');

  modw3s = require('web3.storage');

  modfs = require('fs');

  modos = require('os');

  modpath = require('path');

  modhttp = require('http');

  configActual = JSON.parse(String(modfs.readFileSync("CONFIGME.json")));

  if (!configActual["web3storage-api-key"]) {
    throw new Error("Drop your web3.storage API key into CONFIGME.json to get started.");
  }

  w3s = new modw3s.Web3Storage({
    token: configActual["web3storage-api-key"]
  });

  web3 = new modw3();

  
  // Testing
  queueMicrotask(function() {});

  
  // Themes
  //console.log "Let's have a look",Object.keys(modw3)
  //lst = await  w3s.list({maxResults:10})
  //`for await (const item of lst) {`
  //chk = await item
  //console.log "Maybe",chk
  //`}`
  readThemeSync = function(theme) {
    var snipRead;
    if (/\.\//.test(theme)) {
      throw new Error("Theme name sanity check.");
    }
    
    snipRead = function(snip, ext = 'html') {
      var ee;
      try {
        return String(modfs.readFileSync(`themes/${theme}/${snip}.${ext}`));
      } catch (error) {
        ee = error;
        if (ee.code === 'ENOENT') {
          return String(modfs.readFileSync(`themes/fallback/${snip}.${ext}`));
        }
        throw ee;
      }
    };
    return {
      
      "sys-prelude": snipRead('sys-prelude'),
      "sys-style": snipRead('sys-style'),
      "sys-header": snipRead('sys-header'),
      "page-home": snipRead('page-home'),
      "page-profile": snipRead('page-profile')
    };
  };

  themeActual = readThemeSync(configActual['theme']);

  
  // Helpers
  OK = {
    attr: function(ss) {
      return String(ss).replace(/&/g, '&#x26;').replace(/'/g, '&#x27;').replace(/"/g, '&#x22;');
    },
    html: function(ss) {
      return String(ss).replace(/&/g, '&#x26;').replace(/</g, '&#x3C;');
    }
  };

  ender = function(res, code, more) {
    res.writeHead(code, {
      'Content-Type': 'text/plain',
      'Access-Control-Allow-Origin': '*'
    });
    res.write(`${code}\n`);
    if (more) {
      res.write(`\n${more}\n`);
    }
    return res.end();
  };

  
  // Main
  console.log(["         -= Thought Server on " + modos.hostname() + " =-         "]);

  declareNewPost = function(type, addr, cid, ocb) {
    var fn, step2;
    if (addr.match(/\./)) {
      throw new Error(`Filename compromised: ${addr}`);
    }
    if (addr.match(/[^a-zA-Z0-9]/)) {
      throw new Error(`CID compromised: ${cid}`);
    }
    fn = `db/${addr}.sw`;
    
    //console.log "yay new post for",addr,"-",cid,"\\o/"
    step2 = function(initial) {};
    
    return modfs.readFile(fn, function(er, stored) {
      var initial, lines, modified;
      initial = null;
      if (er) {
        switch (er.code) {
          case 'ENOENT':
            // brand new file
            initial = '';
            break;
          default:
            console.error(er);
            if (typeof ocb === "function") {
              ocb(false);
            }
            throw new Error(`File access problems on ${fn}`);
        }
      } else {
        initial = String(stored);
      }
      
      // step 2
      lines = initial.split('\n');
      lines.unshift(`/post ${cid} @${(new Date()).valueOf()}`);
      modified = lines.join('\n');
      
      return modfs.writeFile(fn, modified, function(er) {
        if (er) {
          console.error("Writing problems", er);
          if (typeof ocb === "function") {
            ocb(false);
          }
          throw new Error(`Saving is Broken: ${fn}`);
        }
        return typeof ocb === "function" ? ocb(true) : void 0;
      });
    });
  };

  
  // Actual
  modhttp.createServer(hanandle = function(req, res) {
    var _, addr, bad, fn, gather, hst, match, pth, rp, siggy, ttl;
    if (req.url.match(/\.\./)) { // no dot-dot requests, anywhere
      return ender(res, 400, '..');
    }
    rp = decodeURI(req.url);
    hst = (req.headers.host || '???').split(':')[0];
    
    rp = rp.split('?')[0];
    if (rp.match(/\/$/)) {
      rp = `${rp}index.html`;
    }
    
    pth = rp.split('/');
    pth = pth.map(function(ss) {
      return ss.toLowerCase();
    });
    console.log(pth);
    if (pth[0]) {
      return ender(res, 400, "Peculiar path.");
    }
    
    if (req.method === 'PUT') {
      if (!(match = rp.match(/^\/post\/0x([0-9A-Fa-f]{40})\/0x([0-9A-Fa-f]{130})$/))) {
        console.log(rp, "ain't puttable.");
        return ender(res, 405, "Put the sword away.");
      }
      [_, addr, siggy] = match;
      
      ttl = 0;
      gather = [];
      bad = false;
      req.on('data', function(intake) {
        if (bad) {
          if (ttl > 0x4000) {
            req.connection.destroy();
          }
          return;
        }
        gather.push(String(intake));
        ttl += intake.length;
        if (ttl > 0x400) {
          return bad = true;
        }
      });
      //req.pipe ws
      req.on('end', async function() {
        var bdy, ee, said, sif, signer, thf;
        if (bad) {
          return ender(res, 413, "tl;dw");
        }
        bdy = gather.join('');
        console.log(`Happily received ${addr}, and`, bdy);
        try {
          
          signer = web3.eth.accounts.recover(bdy, "0x" + siggy);
        } catch (error) {
          ee = error;
          console.warn("web3 hates it:", siggy);
          return ender(res, 400, "Dubious signature error.");
        }
        console.log(signer, "vs.", addr);
        if (signer.toLowerCase() !== "0x" + addr.toLowerCase()) {
          console.log("IMPOSTOR");
          return ender(res, 401, "Sloppy signature error.");
        }
        //else
        console.log("All Clear");
        
        thf = new modw3s.File([bdy], "thought.txt");
        sif = new modw3s.File([
          JSON.stringify({
            eth: addr,
            sig: siggy
          })
        ], "verify.json");
        console.log("Here it goes..");
        said = false;
        try {
          await w3s.put([thf, sif], {
            name: `Thought from ${addr}`,
            onRootCidReady: function(cid) {
              return declareNewPost('post', addr, cid);
            }
          });
          //onStoredChunk: ->
          return ender(res, 204, "");
        } catch (error) {
          ee = error;
          console.warn("Upload likely didn't happen. declareNewPost was called prematurely.", ee);
          return ender(res(502, "Upload was not possible."));
        }
      });
      return;
    }
    
    if (pth[1] === ".well-known") { // add more of these if you want traditional file passthrough serving
      modfs.readFile(rp, function(er, cn) {
        if (er) {
          switch (er.code) {
            case 'ENOENT':
              console.log(req.connection.remoteAddress, "404'd", rp);
              return ender(res, 404);
            default:
              console.log(req.connection.remoteAddress, "500'd", rp);
              return ender(res, 500, er.code);
          }
        }
        res.writeHead(200, {
          'Content-Type': 'application/octet-stream',
          'Cache-Control': `max-age=${0}`
        });
        res.write(cn);
        return res.end();
      });
      return;
    } else if (pth.length === 2 && pth[1] === 'index.html') {
      res.writeHead(200, {
        'Content-Type': 'text/html',
        'Cache-Control': `max-age=${0}`,
        'Access-Control-Allow-Origin': '*'
      });
      res.write([themeActual['sys-prelude'], themeActual['sys-style'], themeActual['sys-header'].replace(/ACF98A03-C0AD-4498-98B9-871F88BE477B/g, hst), themeActual['page-home']].join('\n'));
      res.end();
      return;
    } else if (pth.length === 3 && pth[1].match(/[a-z0-9]{40}/)) {
      fn = `db/${pth[1]}.sw`;
      
      modfs.readFile(fn, function(er, stored) {
        var send;
        if (er) {
          switch (er.code) {
            case 'ENOENT':
              // no such home
              return ender(res, 404, "No such number.");
            default:
              console.error("File access problems", er);
              return ender(res, 500, "Something is not right.");
          }
        }
        
        // Overzealously disallow characters that could cause code injection
        send = String(stored);
        if (/[`\\<"&]/.test(send)) {
          console.warn("Skipped sending contents of", fn, "through text/html due to possible injection.");
          return ender(res, 503, "Apparent data corruption.");
        }
        
        // Ready to send:
        res.writeHead(200, {
          'Content-Type': 'text/html',
          'Cache-Control': `max-age=${0}`,
          'Access-Control-Allow-Origin': '*'
        });
        res.write([themeActual['sys-prelude'], themeActual['sys-style'], themeActual['sys-header'].replace(/ACF98A03-C0AD-4498-98B9-871F88BE477B/g, hst), themeActual['page-profile'].replace(/ADF26198-411C-414A-9EB3-2C981305110E/g, send)].join('\n'));
        return res.end();
      });
      return;
    }
    //else

    return ender(res, 400, "Not available.");
  }).listen(configActual["www-port"]);

  // auto-reload for cmd line stuff
  wayout = false;

  modfs.watch('.', function(tx, fn) {
    if (wayout) {
      return;
    }
    if (tx === 'change') {
      console.log(`Root file changed: "${tx}" / "${fn}" `);
      // Restart server when either of these files changes:
      if ((fn.match(/\bapp\.js$/i)) || (fn.match(/\bconfigme\.json$/i)) || (fn.match(/\bbump\.uid$/i))) {
        wayout = true;
        console.log('-- Reboot --');
        //!!#md_save()
        return probably_shut_it_down();
      }
    }
  });

  try {
    modfs.watch('./themes/', {
      recursive: true
    }, function(tx, fn) {
      if (wayout) {
        return;
      }
      if (tx === 'change') {
        console.log(`Theme file changed: "${tx}" / "${fn}" `);
        // Restart server when either of these files changes:
        if ((fn.match(/\.html$/i)) || (fn.match(/\.css$/i))) {
          wayout = true;
          console.log('-- Reboot --');
          //!!#md_save()
          return probably_shut_it_down();
        }
      }
    });
  } catch (error) {}

  // I feel like I'm gonna ctrl-c absent-mindedly and lose a bunch of data some time
  seriously = 0;

  process.on('SIGINT', function() {
    seriously += 1;
    switch (seriously) {
      case 1:
        return console.log("First Ctrl-C absorbed. 2 to go.");
      case 2:
        return console.log("Last Ctrl-C absorbed. Next terminates.");
      case 4:
        console.log("Impolitely terminating.");
        return process.exit(92);
      default:
        console.log("Politely terminating.");
        //!!#md_save()
        return probably_shut_it_down();
    }
  });

  sys_pending_shutdown = false;

  probably_shut_it_down = function() {
    //!!#if busy_saving
    //!!#	sys_pending_shutdown = yes
    //!!#else
    return shut_it_down();
  };

  shut_it_down = function() {
    return setTimeout(function() {
      if (seriously >= 3) {
        return process.exit(90);
      } else {
        return process.exit(99);
      }
    }, 125);
  };

}).call(this);
