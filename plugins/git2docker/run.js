var Tail = require('always-tail');
var auth = require('basic-auth');
var bcrypt = require('bcrypt');
var pushover = require('pushover');
var spawn = require('child_process').spawn;
var exec = require('child_process').exec;
var fs = require('fs');
var url = require('url');
var path = require('path');

var options = require(process.env.OPTIONS_JSON || './options.json');
var repos = pushover(options.repos);
var runtime = { connectionCount: 0 };
var repositories = require(process.env.REPOSITORIES_JSON || './repositories.json');

options.port = options.port || 30003;

function rmDir(dirPath) {
    var files = [];
    try {
        files = fs.readdirSync(dirPath);
    } catch (e) {
        return;
    }
    if (files.length > 0)
        for (var i = 0; i < files.length; i++) {
            var filePath = dirPath + '/' + files[i];
            if (fs.statSync(filePath).isFile())
                fs.unlinkSync(filePath);
            else
                rmDir(filePath);
        }
    fs.rmdirSync(dirPath);
};

function execCmd(cmds, logStream) {
    return new Promise(function(resolve) {
        var cmd = options.cmdPrefix + ' sh -c "' + cmds.join(' && ') + '"';
        var proc = exec(cmd);

        proc.stdout.setEncoding('utf8');
        proc.stdout
            .pipe(logStream, {end: false});

        proc.stderr.setEncoding('utf8');
        proc.stderr
            .pipe(logStream, {end: false});

        proc.on('exit', function (code, signal) {
            console.log(cmd+': '+code+'\n\n');
            logStream.write(cmd+': '+code+'\n\n');
            resolve();
        });
    });
}

repos.on('push', function (push) {
    var logPath = path.join(options.logs, ['git2docker', push.repo, push.branch].join('_')+'.log');
    var logStream = fs.createWriteStream(logPath);

    var script = path.join(__dirname, 'build.sh');
    var exists = fs.existsSync(script);
    if (!exists || !repositories[push.repo] || repositories[push.repo].branch !== push.branch) {
        console.log('push reject ' + push.repo + '/' + push.commit + ' (' + push.branch + ') cwd:' + cwd);
        return push.reject();
    }

    var cwd = fs.existsSync(push.cwd) && push.cwd;
    cwd = cwd || fs.existsSync(push.cwd+'.git') && (push.cwd+'.git');

    console.log('push ' + push.repo + '/' + push.commit + ' (' + push.branch + ') cwd:' + cwd);

    push.on('success', function() {console.log('success');});

    push.on('exit', function(code) {
        console.log('push code:', code);
        if (code !== 0) {
            return;
        }
        var proc = spawn(script, [push.repo, push.commit, push.branch, repositories[push.repo].registry || ''], {cwd: cwd});

        proc.stdout.setEncoding('utf8');
        proc.stdout
            .pipe(logStream, {end: false});

        proc.stderr.setEncoding('utf8');
        proc.stderr
            .pipe(logStream, {end: false});

        proc.on('exit', function (code, signal) {
            console.log(script+': '+code+'\n\n');
            logStream.write(script+': '+code+'\n\n');
            if (cwd.startsWith(options.repos)) {
                rmDir(cwd);
            }
            if (repositories[push.repo].cmd) {
                execCmd(repositories[push.repo].cmd, logStream)
                    .then(function() {
                        logStream.end();
                    })
                    .catch(function(err) {
                        console.error(err.stack||err.message||err);
                    });
            } else {
                logStream.end();
            }
        });
    });

    push.accept();
});

repos.on('fetch', function (fetch) {
    console.log('fetch ' + fetch.repo + '/' + fetch.commit);
    fetch.accept();
});

bcrypt.genSalt(3, function(err, salt) {
    bcrypt.hash(options.password, salt, function(err, hash) {
        options.hash = hash;
    });
});

var http = require('http');
var server = http.createServer(function (req, res) {
    console.log(new Date(), req.method, req.url)
    var credentials = auth(req);

    new Promise(function(resolve, reject) {
        if (!credentials || credentials.name !== options.username || !credentials.pass) {
            return reject("Missing credentials");
        }
        bcrypt.compare(credentials.pass, options.hash, function(err, ok) {
            if(!err && ok){
                resolve();
            }else{
                reject(err);
            }
        });
    })
    .then(function() {
        var urlData = url.parse(req.url, true) || {};
        if (urlData.query && urlData.query.repo && urlData.query.branch) {
            var fs = require('fs');
            var filename = path.join(options.logs, ['git2docker', urlData.query.repo, urlData.query.branch].join('_')+'.log');

            if (!fs.existsSync(filename) || filename.indexOf('..') !== -1) {
                res.statusCode = 400;
                res.end('bad request');
            }

            var size = fs.statSync(filename).size;
            var opts = { interval: 1000 };
            if (typeof size === 'number') {
                opts.start = size > 4096 ? size - 4096 : 0;
            }
            var tail = new Tail(filename, '\n', opts);

            tail.on('line', function(data) {
                res.write(data+'\n');
            });

            tail.on('error', function(data) {
                console.error('tail error:', data);
                res.end();
                tail.unwatch();
            });

            console.time('tail: '+filename);
            runtime.connectionCount++;
            res.setHeader('Transfer-Encoding', 'chunked');
            res.setHeader('Content-Type', 'text/plain');

            res.on('close', function() {
                console.timeEnd('tail: '+filename);
                runtime.connectionCount--;

                if (runtime.connectionCount < 1) {
                    setTimeout(function() {
                        tail.unwatch();
                        res.end();
                    }, 1000);
                }
            });

            tail.watch();
        } else {
            repos.handle(req, res);
        }
    })
    .catch(function(err) {
        res.statusCode = 401;
        res.setHeader('WWW-Authenticate', 'Basic realm="Enter credentials"');
        res.end('Access denied');
    });
});

server.listen(options.port);
