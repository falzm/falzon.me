---
type: post
title: bURL - A Pure Bash HTTP Client
date: 2015-09-19
tags:
- HTTP
- bash
- shell
keywords:
- HTTP
- bash
- shell
---

This weekend's silly project is **bURL**, a trivial HTTP client implemented in pure [GNU Bash][1] script. It's been inspired by *shudder's guide to network programming in bash* – unfortunately disappeared from the known internet, but you can still read it [on archive.org][0].

The initial goal to reach was to be able to download a file in a basic Linux environment without using [cURL][3], [wget][2] or even [Netcat][4]. I started to wonder if it could be done in pure Bash script – especially since I found out about Bash's [network socket capabilities][5] –, without even calling a local UNIX command such as `cat` or `grep`.

This exercise is also a nice refresher about one of the most basic shell notions: [redirections][5]. Here is a breakdown of the script's inner mechanism.

Quick reminder: on most UNIX systems, a process gets 3 standard file descriptors opened by the shell is it executed in. Those FD are:

* standard input (*stdin*): 0
* standard output (*stdout*): 1
* standard error (*stderr*): 2

First, we open a TCP/IP network socket to host *baha.mu* on port 80 tied to a new file descriptor (3); this FD is opened bidirectionally, since we'll use it both to send a HTTP request to and read the response from:

```shell
exec 3<>/dev/tcp/baha.mu/80
```

Then we send a HTTP request to this FD...

```shell
printf "GET / HTTP/1.1\nHost: baha.mu\nUser-Agent: bURL/Bash ${BASH_VERSION}\n\n" >&3
```

...and we read the response that has been returned by the HTTP server from the same FD and write it to the standard input FD (0):

```shell
IFS=
while read -r -t 1 line 0<&3; do
    line=${line//$'\r'}
    echo "$line"
done
```

Finally, we close the network connection to the HTTP server:

```shell
exec 3<&-
```

Observations:

* The `IFS` variable has to been set to a null value to prevent Bash from performing line splitting based on some characters using `read`.
* We strip the `\r` ([carriage return character][7]) on each line.
* `-t 1` option passed to `read` explicitly exits after 1 second if the HTTP server observes a connection *keep-alive* delay after serving the request.

The code is available [on Github][6].

[0]: https://web.archive.org/web/20120818034606/http://shudder.daemonette.org/source/BashNP-Guide.txt
[1]: https://www.gnu.org/software/bash/
[2]: https://www.gnu.org/software/wget/
[3]: http://curl.haxx.se/
[4]: http://nc110.sourceforge.net/
[5]: https://www.gnu.org/software/bash/manual/html_node/Redirections.html#Redirections
[6]: https://github.com/falzm/burl
[7]: https://en.wikipedia.org/wiki/Carriage_return
